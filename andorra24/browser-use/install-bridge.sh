#!/usr/bin/env bash
# Install ONLY on previously authorized runner, without changing LIVE.
set -Eeuo pipefail
umask 077
meta() { curl -fsS -m 5 -H 'Metadata-Flavor: Google' "http://metadata.google.internal/computeMetadata/v1/$1"; }
[[ "$EUID" -eq 0 ]] || { echo "Use sudo on existing runner" >&2; exit 1; }
[[ "$(meta instance/name)" == andorra24-runway-runner && "$(meta project/project-id)" == andorra-24-live ]] || { echo "Refusing: wrong VM or project" >&2; exit 2; }
APP=/opt/andorra24-browser-use
STATE=/var/lib/andorra24-browser-use
USER_NAME=andorra24browser
[[ -x "$APP/.venv/bin/python" ]] || { echo "Existing Browser Use environment missing" >&2; exit 3; }
[[ -r "$1" ]] || { echo "Bridge source missing" >&2; exit 3; }
id "$USER_NAME" >/dev/null
install -m 0750 -o "$USER_NAME" -g "$USER_NAME" "$1" "$APP/bridge.py"
"$APP/.venv/bin/python" -m py_compile "$APP/bridge.py"
install -d -m 0700 /etc/andorra24-browser-use
cat >/etc/systemd/system/andorra24-n8n-bridge-selftest.service <<'UNIT'
[Unit]
Description=ANDORRA 24 n8n browser control preflight
[Service]
Type=oneshot
User=andorra24browser
Group=andorra24browser
Environment=HOME=/var/lib/andorra24-browser-use
WorkingDirectory=/opt/andorra24-browser-use
ExecStart=/opt/andorra24-browser-use/.venv/bin/python /opt/andorra24-browser-use/bridge.py --selftest
NoNewPrivileges=yes
UMask=0077
UNIT
cat >/etc/systemd/system/andorra24-n8n-bridge.service <<'UNIT'
[Unit]
Description=ANDORRA 24 authenticated outbound-only n8n bridge
After=network-online.target
Wants=network-online.target
ConditionPathExists=/etc/andorra24-browser-use/bridge.env
[Service]
Type=simple
User=andorra24browser
Group=andorra24browser
Environment=HOME=/var/lib/andorra24-browser-use
EnvironmentFile=/etc/andorra24-browser-use/bridge.env
WorkingDirectory=/opt/andorra24-browser-use
ExecStart=/opt/andorra24-browser-use/.venv/bin/python /opt/andorra24-browser-use/bridge.py
Restart=on-failure
RestartSec=15
NoNewPrivileges=yes
UMask=0077
[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl start andorra24-n8n-bridge-selftest.service
journalctl -u andorra24-n8n-bridge-selftest.service -n 10 --no-pager
if [[ -s /etc/andorra24-browser-use/bridge.env ]]; then
 systemctl enable --now andorra24-n8n-bridge.service
 echo "BRIDGE_ENABLED"
else
 echo "BRIDGE_INSTALLED_NOT_CONNECTED: n8n endpoints and secret are not configured"
fi
echo "EXISTING_LIVE_UNTOUCHED"
