#!/usr/bin/env bash
# ANDORRA 24 - installs Browser Use + Playwright ONLY on existing runner VM.
set -Eeuo pipefail
umask 027
META=http://metadata.google.internal/computeMetadata/v1
metadata() { curl -fsS --max-time 5 -H 'Metadata-Flavor: Google' "$META/$1"; }
if [[ "$EUID" -ne 0 ]]; then echo 'Run with sudo on runner VM only' >&2; exit 1; fi
for c in curl apt-get systemctl runuser; do command -v "$c" >/dev/null || exit 1; done
instance="$(metadata instance/name)" || { echo 'No authenticated GCE metadata' >&2; exit 1; }
project="$(metadata project/project-id)" || exit 1
if [[ "$instance" != "andorra24-runway-runner" || "$project" != "andorra-24-live" ]]; then
  echo "REFUSING wrong VM: $instance / $project" >&2
  exit 2
fi
APP=/opt/andorra24-browser-use
STATE=/var/lib/andorra24-browser-use
USER_NAME=andorra24browser
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y --no-install-recommends python3 python3-venv python3-pip ca-certificates curl libnss3 libnspr4
if ! id "$USER_NAME" >/dev/null 2>&1; then
  useradd --system --user-group --home-dir "$STATE" --create-home --shell /usr/sbin/nologin "$USER_NAME"
fi
install -d -m 0750 -o "$USER_NAME" -g "$USER_NAME" "$APP" "$STATE"
HERE="$(cd "$(dirname "$0")" && pwd -P)"
install -m 0750 -o "$USER_NAME" -g "$USER_NAME" "$HERE/preflight.py" "$APP/preflight.py"
if [[ ! -x "$APP/.venv/bin/python" ]]; then
  runuser -u "$USER_NAME" -- python3 -m venv "$APP/.venv"
fi
runuser -u "$USER_NAME" -- "$APP/.venv/bin/python" -m pip install --disable-pip-version-check --upgrade pip
runuser -u "$USER_NAME" -- "$APP/.venv/bin/python" -m pip install --disable-pip-version-check browser-use playwright
"$APP/.venv/bin/python" -m playwright install-deps chromium
runuser -u "$USER_NAME" -- "$APP/.venv/bin/python" -m playwright install chromium
chown -R "$USER_NAME:$USER_NAME" "$APP" "$STATE"
cat > /etc/systemd/system/andorra24-browser-preflight.service <<'UNIT'
[Unit]
Description=ANDORRA 24 Browser Use and Playwright smoke check only
After=network-online.target
Wants=network-online.target
[Service]
Type=oneshot
User=andorra24browser
Group=andorra24browser
WorkingDirectory=/opt/andorra24-browser-use
ExecStart=/opt/andorra24-browser-use/.venv/bin/python /opt/andorra24-browser-use/preflight.py
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/lib/andorra24-browser-use
UMask=0077
TimeoutStartSec=120
UNIT
cat > /etc/systemd/system/andorra24-browser-preflight.timer <<'UNIT'
[Unit]
Description=Hourly Browser Use preflight without generating videos
[Timer]
OnCalendar=hourly
Persistent=true
RandomizedDelaySec=120
Unit=andorra24-browser-preflight.service
[Install]
WantedBy=timers.target
UNIT
systemctl daemon-reload
systemctl enable --now andorra24-browser-preflight.timer
systemctl start andorra24-browser-preflight.service
systemctl is-active --quiet andorra24-browser-preflight.timer
printf '\nINSTALL_OK: Browser Use + Playwright on %s (%s)\n' "$instance" "$project"
printf 'PENDING: authorized Runway Web session, n8n integration, video/publish workflow.\n'
