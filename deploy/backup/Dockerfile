# Ops toolbox for the stack: psql / pg_dump / pg_restore 16 + rclone + curl.
# Default command = the nightly backup (backup.sh), run by the host crontab with
#   ./deploy/compose.sh run --rm -T backup
# Any other command works too: `./deploy/compose.sh run --rm backup psql`, or deploy/db/apply.sh (compose mounts
# deploy/db and deploy/lib under /srv/deploy; backup.sh sources /srv/deploy/lib/telegram.sh). Build context: deploy/backup.
FROM alpine:3.22.6
RUN apk add --no-cache bash postgresql16-client rclone curl tzdata coreutils findutils
ENV TZ=UTC
COPY --chmod=0755 backup.sh /usr/local/bin/backup.sh
WORKDIR /backups
CMD ["/usr/local/bin/backup.sh"]
