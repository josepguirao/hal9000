#!/usr/bin/env bash
# Upgrade ONLY the existing diagnostic bridge to a domain-limited Playwright UI worker.
set -Eeuo pipefail
umask 077
meta(){ curl -fsS -m 5 -H 'Metadata-Flavor: Google' "http://metadata.google.internal/computeMetadata/v1/$1"; }
[[ "$EUID" -eq 0 ]] || { echo 'NEED_SUDO'; exit 2; }
[[ "$(meta instance/name)" == 'andorra24-runway-runner' && "$(meta project/project-id)" == 'andorra-24-live' ]] || { echo 'WRONG_VM_REFUSED'; exit 3; }
APP=/opt/andorra24-browser-use
ENV_FILE=/etc/andorra24-browser-use/bridge.env
VENV=$APP/.venv/bin/python
[[ -x "$VENV" && -s "$ENV_FILE" ]] || { echo 'EXISTING_BRIDGE_NOT_CONFIGURED';exit 4; }
id andorra24browser >/dev/null
REF=41133daebc5ba91bf29330e1c1f545d67a17d2f7
ROOT=https://raw.githubusercontent.com/josepguirao/hal9000
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
curl -fsSL "$ROOT/$REF/andorra24/browser-use/browser_actions.py" -o "$TMP/browser_actions.py"
curl -fsSL "$ROOT/$REF/andorra24/browser-use/bridge-v2.py" -o "$TMP/bridge-v2.py"
"$VENV" -m py_compile "$TMP/browser_actions.py" "$TMP/bridge-v2.py"
install -m 0640 -o andorra24browser -g andorra24browser "$TMP/browser_actions.py" "$APP/browser_actions.py"
install -m 0750 -o andorra24browser -g andorra24browser "$TMP/bridge-v2.py" "$APP/bridge-v2.py"
mkdir -p /etc/systemd/system/andorra24-n8n-bridge.service.d
cat >/etc/systemd/system/andorra24-n8n-bridge.service.d/20-browser-task.conf <<'UNIT'
[Service]
ExecStart=
ExecStart=/opt/andorra24-browser-use/.venv/bin/python /opt/andorra24-browser-use/bridge-v2.py
UNIT
chmod 0644 /etc/systemd/system/andorra24-n8n-bridge.service.d/20-browser-task.conf
# Check using existing service account; does not contact Runway or spend credits.
runuser -u andorra24browser -- env HOME=/var/lib/andorra24-browser-use "$VENV" "$APP/bridge-v2.py" --selftest >/dev/null
systemctl daemon-reload
systemctl restart andorra24-n8n-bridge.service
systemctl enable andorra24-n8n-bridge.service >/dev/null
sleep 3
systemctl is-active --quiet andorra24-n8n-bridge.service || { echo 'SERVICE_FAILED'; exit 5; }
echo 'BROWSER_TASK_EXECUTOR_INSTALLED_AND_RUNNING'
echo 'ALLOWED_SITES=n8n,runway,youtube,drive'
echo 'LIVE_SERVER_UNTOUCHED'
