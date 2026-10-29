# Security policy

Quidditch Manager is a free fan project. The desktop game is offline, but the browser version has a small accounts
service (`server/`) that keeps players' email addresses and profiles, so security reports matter to us.

## Reporting a vulnerability

**Please do not open a public issue, discussion or pull request for a vulnerability.**

- Preferred: GitHub's private vulnerability reporting. Open the repository's **Security** tab and choose
  **Report a vulnerability**. Only the maintainers see the report.
- Or email **quidditchmanagerxyz@gmail.com**.

Include what you can of:

- what is affected (a route, a file, a page) and what an attacker could do;
- steps to reproduce, or a proof of concept against **your own local copy**;
- the version or commit you tested.

## What to expect

This is a hobby project, so these are best-effort targets, not promises:

- an acknowledgement within 7 days;
- an assessment, and a plan or a fix, within 30 days for serious issues;
- a note in the release that fixes it, crediting you if you want to be named.

There is no bug bounty.

## Scope

In scope:

- the accounts service in `server/`: sign-in (email link and Google), sessions, the `/play/` gate, registration, the
  account page, data export and deletion;
- the deployment configuration in `deploy/` (Compose, Caddy, Postgres, backups) and the CI workflows in `.github/`;
- how the game loads in the browser (`src/game/platform.gd` and the Godot web export);
- the game's save import (`.qmsave` files are untrusted input).

Out of scope:

- denial of service through sheer volume, and rate limits that work as documented;
- reports from automated scanners without a demonstrated impact;
- missing security headers on pages that do not need them, or the documented temporary
  Content-Security-Policy on `/play/` (see `docs/design/12-web-version.md`);
- social engineering, physical attacks, and the infrastructure of Cloudflare, Hetzner, Google, Resend, Backblaze or
  GitHub themselves (report those to them).

## Rules for testing

Good-faith research within these rules is welcome, and we will not take action against it:

- Test against a local copy whenever you can. `server/README.md` explains how to run the service with a local
  database, and in development the sign-in link is printed to the console, so no email is needed.
- On the live site, use only accounts you own. Do not access, change or delete other people's data, do not send
  email to addresses that are not yours, and do not degrade the service for others.
- If you reach personal data by accident, stop, do not keep it, and tell us.
- Give us a reasonable time to fix the issue before you disclose it publicly.

## Supported versions

Only the latest release and the `main` branch get security fixes. The live site always runs the latest release.
