#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${REPO_URL:-}"
REPO_BRANCH="${REPO_BRANCH:-main}"
APP_DIR="${APP_DIR:-/srv/quidditch-manager}"
DATA_DIR="${DATA_DIR:-/srv/quidditch-manager-data}"
APP_USER="${APP_USER:-qm}"
TS_HOSTNAME="${TS_HOSTNAME:-quidditch-manager}"
FIREWALL_LOCK="${FIREWALL_LOCK:-ask}"
KEY_ARG="${1:-${SSH_PUBKEY:-}}"
LOG_DIR=/var/log/quidditch-manager

[[ $EUID -eq 0 ]] || { echo "run as root"; exit 1; }
[[ "$APP_USER" =~ ^[a-z][a-z0-9_-]{0,30}$ ]] || { echo "bad APP_USER"; exit 2; }
if [[ -z "$KEY_ARG" ]]; then
  KEY_ARG="$(grep -E '^(ssh-|ecdsa-|sk-)' /root/.ssh/authorized_keys 2>/dev/null | head -1 || true)"
  [[ -n "$KEY_ARG" ]] && echo "using root's authorized key for $APP_USER"
fi
[[ -n "$KEY_ARG" ]] || { echo "usage: bootstrap.sh '<ssh public key>' | bootstrap.sh /path/to/key.pub (or SSH_PUBKEY=…)"; exit 2; }
if [[ -f "$KEY_ARG" ]]; then PUBKEY="$(grep -E '^(ssh-|ecdsa-|sk-)' "$KEY_ARG" | head -1 || true)"; else PUBKEY="$KEY_ARG"; fi
[[ "$PUBKEY" =~ ^(ssh-|ecdsa-|sk-) ]] || { echo "that does not look like an SSH public key"; exit 2; }

step() { printf '\n== %s\n' "$*"; }
export DEBIAN_FRONTEND=noninteractive

step "1. user $APP_USER, SSH keys only"
if ! id -u "$APP_USER" >/dev/null 2>&1; then
  adduser --disabled-password --gecos "" "$APP_USER"
fi
usermod -aG sudo "$APP_USER"
echo "$APP_USER ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/90-$APP_USER"
chmod 440 "/etc/sudoers.d/90-$APP_USER"
visudo -cf "/etc/sudoers.d/90-$APP_USER" >/dev/null
install -d -m 700 -o "$APP_USER" -g "$APP_USER" "/home/$APP_USER/.ssh"
touch "/home/$APP_USER/.ssh/authorized_keys"
grep -qxF "$PUBKEY" "/home/$APP_USER/.ssh/authorized_keys" || echo "$PUBKEY" >> "/home/$APP_USER/.ssh/authorized_keys"
chmod 600 "/home/$APP_USER/.ssh/authorized_keys"
chown -R "$APP_USER:$APP_USER" "/home/$APP_USER/.ssh"

# sshd takes the first value it reads: this drop-in sorts before 50-cloud-init.conf.
cat > /etc/ssh/sshd_config.d/00-quidditch-manager.conf <<'SSHD'
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
PermitRootLogin prohibit-password
X11Forwarding no
MaxAuthTries 4
ClientAliveInterval 120
SSHD
sshd -t && systemctl reload ssh
echo "   sshd: passwords off, keys only"

step "2. packages, UTC, Docker, Tailscale, fail2ban, unattended-upgrades"
timedatectl set-timezone UTC
apt-get update -q
apt-get install -y -q ca-certificates curl gnupg git ufw fail2ban unattended-upgrades jq unzip brotli logrotate

if ! command -v docker >/dev/null 2>&1; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  # shellcheck disable=SC1091
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -q
  apt-get install -y -q docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi
DAEMON_JSON='{ "log-driver": "json-file", "log-opts": { "max-size": "10m", "max-file": "5" }, "icc": false, "live-restore": true }'
if [[ "$(cat /etc/docker/daemon.json 2>/dev/null || true)" != "$DAEMON_JSON" ]]; then
  echo "$DAEMON_JSON" > /etc/docker/daemon.json
  systemctl restart docker
fi
systemctl enable --now docker
usermod -aG docker "$APP_USER"
echo "   docker $(docker --version | cut -d, -f1 | awk '{print $3}'), compose $(docker compose version --short)"

if ! command -v tailscale >/dev/null 2>&1; then
  curl -fsSL https://tailscale.com/install.sh | sh
fi
systemctl enable --now tailscaled

cat > /etc/fail2ban/jail.local <<'F2B'
[DEFAULT]
backend  = systemd
bantime  = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
F2B
systemctl enable --now fail2ban
systemctl restart fail2ban

cat > /etc/apt/apt.conf.d/20auto-upgrades <<'APT'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
APT
cat > /etc/apt/apt.conf.d/52quidditch-manager-unattended <<'APT'
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "05:30";
APT
systemctl enable --now unattended-upgrades
echo "   unattended-upgrades on (reboot 05:30 UTC when required; containers restart on their own)"

step "3. Tailscale"
if tailscale status >/dev/null 2>&1 && [[ -n "$(tailscale ip -4 2>/dev/null)" ]]; then
  echo "   already up"
else
  if [[ -n "${TAILSCALE_AUTHKEY:-}" ]]; then
    tailscale up --authkey "$TAILSCALE_AUTHKEY" --hostname "$TS_HOSTNAME"
  else
    echo "   open the URL below in a browser to add this box to your tailnet"
    tailscale up --hostname "$TS_HOSTNAME"
  fi
fi
TS_IP="$(tailscale ip -4 2>/dev/null || true)"

step "4. checkout, data directories, .env, crontab, logs"
if [[ ! -d "$APP_DIR/.git" ]]; then
  [[ -n "$REPO_URL" ]] || { echo "REPO_URL is required for the first clone (https://github.com/<owner>/<repo>.git)"; exit 2; }
  install -d -o "$APP_USER" -g "$APP_USER" "$APP_DIR"
  sudo -u "$APP_USER" git clone --branch "$REPO_BRANCH" "$REPO_URL" "$APP_DIR"
else
  sudo -u "$APP_USER" git -C "$APP_DIR" pull --ff-only || echo "   (git pull skipped: local changes?)"
fi
install -d -m 755 -o "$APP_USER" -g "$APP_USER" "$DATA_DIR" "$DATA_DIR/web" "$DATA_DIR/web/releases" "$DATA_DIR/state"
install -d -m 700 -o "$APP_USER" -g "$APP_USER" "$DATA_DIR/backups"
install -d -m 755 -o "$APP_USER" -g "$APP_USER" "$LOG_DIR" /var/tmp/quidditch-manager-health

ENV_FILE="$APP_DIR/.env"
if [[ ! -f "$ENV_FILE" ]]; then
  install -m 600 -o "$APP_USER" -g "$APP_USER" "$APP_DIR/deploy/env.example" "$ENV_FILE"
  echo "   $ENV_FILE created from deploy/env.example"
fi
chmod 600 "$ENV_FILE"; chown "$APP_USER:$APP_USER" "$ENV_FILE"
set_env() {
  if grep -qE "^$1=.+" "$ENV_FILE"; then return 1; fi
  if grep -qE "^$1=" "$ENV_FILE"; then sed -i "s|^$1=\$|$1=$2|" "$ENV_FILE"; else printf '%s=%s\n' "$1" "$2" >> "$ENV_FILE"; fi
}
for k in POSTGRES_PASSWORD DB_API_PASSWORD; do
  set_env "$k" "$(openssl rand -hex 24)" && echo "   generated $k"
done
set_env AUTH_SECRET "$(openssl rand -hex 32)" && echo "   generated AUTH_SECRET"
sed -i "s|^QM_UID=.*|QM_UID=$(id -u "$APP_USER")|; s|^QM_GID=.*|QM_GID=$(id -g "$APP_USER")|; s|^QM_DATA_DIR=.*|QM_DATA_DIR=$DATA_DIR|" "$ENV_FILE"

sed "s|/srv/quidditch-manager|$APP_DIR|g; s|/var/log/quidditch-manager|$LOG_DIR|g" "$APP_DIR/deploy/crontab" | crontab -u "$APP_USER" -
cat > /etc/logrotate.d/quidditch-manager <<LR
$LOG_DIR/*.log {
  weekly
  rotate 8
  compress
  missingok
  notifempty
  copytruncate
}
LR
echo "   crontab installed for $APP_USER (crontab -u $APP_USER -l); logs in $LOG_DIR"

step "5. firewall (ufw): inbound only 22/tcp on tailscale0"
# A re-run must never leave an already active firewall disabled (`ufw --force reset` turns it off).
was_active=0
ufw status 2>/dev/null | grep -q '^Status: active' && was_active=1
ufw --force reset >/dev/null
ufw default deny incoming >/dev/null
ufw default allow outgoing >/dev/null
ufw allow in on tailscale0 to any port 22 proto tcp comment 'ssh over tailscale' >/dev/null
ufw logging low >/dev/null
lock=no
if [[ -z "$TS_IP" ]]; then
  echo "   Tailscale is not up: ufw NOT enabled (you would lock yourself out). Re-run after tailscale up."
elif [[ "$FIREWALL_LOCK" == yes || "$was_active" == 1 ]]; then
  lock=yes
elif [[ "$FIREWALL_LOCK" == ask && -r /dev/tty ]]; then
  echo "   In ANOTHER terminal, check that this works:   ssh $APP_USER@<tailscale name or $TS_IP>"
  read -r -p "   Enable the firewall now (public port 22 closes)? [yes/no] " ans < /dev/tty || ans=no
  [[ "$ans" == yes ]] && lock=yes
fi
if [[ "$lock" == yes ]]; then
  ufw --force enable >/dev/null
  echo "   ufw enabled; now attach the Hetzner Cloud Firewall with NO inbound rules (deploy/README.md)"
else
  echo "   ufw rules staged, NOT enabled. Once SSH over Tailscale works: ufw --force enable (or FIREWALL_LOCK=yes)"
fi
# Note: Docker publishes ports through its own iptables chains, before ufw. compose.yml only ever binds
# 127.0.0.1, so nothing is reachable from outside even so.

cat <<MSG

done. Next, as $APP_USER over Tailscale (deploy/README.md, "First rollout"):
  1. fill $ENV_FILE (SITE_URL, RELEASE_REPO, Google, Resend, B2, …)
  2. cd $APP_DIR && ./deploy/update.sh --target stack <version>
  3. CLOUDFLARE_TUNNEL_TOKEN in .env, then ./deploy/update.sh --target edge
MSG
