#!/usr/bin/env bash
# One-time, SSH-tunnel-only remote Runway login portal. Never expose VNC publicly.
set -Eeuo pipefail
umask 077
META=http://metadata.google.internal/computeMetadata/v1
meta() { curl -fsS --max-time 5 -H 'Metadata-Flavor: Google' "$META/$1"; }
[[ "$EUID" -eq 0 ]] || { echo "Run as root on approved runner" >&2; exit 1; }
INSTANCE="$(meta instance/name)"
PROJECT="$(meta project/project-id)"
[[ "$INSTANCE" == "andorra24-runway-runner" && "$PROJECT" == "andorra-24-live" ]] || { echo "REFUSING wrong VM $INSTANCE/$PROJECT" >&2; exit 2; }
USER_NAME=andorra24browser
APP=/opt/andorra24-browser-use
STATE=/var/lib/andorra24-browser-use
[[ -x "$APP/.venv/bin/python" ]] || { echo "Browser Use missing" >&2; exit 3; }
id "$USER_NAME" >/dev/null
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y --no-install-recommends xvfb x11vnc novnc websockify xauth openssl
install -d -m 0700 -o "$USER_NAME" -g "$USER_NAME" "$STATE/runway-profile"
install -d -m 0700 /etc/andorra24-browser-use
# Xauthority must exist before xauth. Repair any incomplete earlier install.
touch "$STATE/.Xauthority"
chown "$USER_NAME:$USER_NAME" "$STATE/.Xauthority"
chmod 0600 "$STATE/.Xauthority"
runuser -u "$USER_NAME" -- xauth -f "$STATE/.Xauthority" add :99 . "$(openssl rand -hex 16)"
if [[ ! -f "$STATE/vnc-password" ]]; then
  vnc_pw="$(openssl rand -hex 4)"
  printf '%s\n' "$vnc_pw" >/etc/andorra24-browser-use/vnc-readable-on-runner.txt
  chmod 0600 /etc/andorra24-browser-use/vnc-readable-on-runner.txt
  x11vnc -storepasswd "$vnc_pw" "$STATE/vnc-password" >/dev/null 2>&1
fi
chown "$USER_NAME:$USER_NAME" "$STATE/.Xauthority" "$STATE/vnc-password"
chmod 0600 "$STATE/vnc-password"
ROOT=https://raw.githubusercontent.com/josepguirao/hal9000/0209f24a23235937fe4717a52f1d656417f18745/andorra24/browser-use
curl -fsSL "$ROOT/runway-login.py" -o "$APP/runway-login.py"
chown "$USER_NAME:$USER_NAME" "$APP/runway-login.py"
chmod 0750 "$APP/runway-login.py"
cat >/etc/systemd/system/andorra24-runway-login-display.service <<'UNIT'
[Unit]
Description=ANDORRA24 temporary X display for one-time human Runway login
[Service]
Type=simple
User=andorra24browser
Group=andorra24browser
Environment=HOME=/var/lib/andorra24-browser-use
ExecStart=/usr/bin/Xvfb :99 -auth /var/lib/andorra24-browser-use/.Xauthority -screen 0 1360x760x24 -nolisten tcp
Restart=on-failure
NoNewPrivileges=yes
UNIT
cat >/etc/systemd/system/andorra24-runway-login-browser.service <<'UNIT'
[Unit]
Description=ANDORRA24 human-operated Runway Chrome browser (no automations)
Requires=andorra24-runway-login-display.service
After=andorra24-runway-login-display.service
[Service]
Type=simple
User=andorra24browser
Group=andorra24browser
Environment=HOME=/var/lib/andorra24-browser-use
Environment=DISPLAY=:99
Environment=XAUTHORITY=/var/lib/andorra24-browser-use/.Xauthority
WorkingDirectory=/opt/andorra24-browser-use
ExecStart=/opt/andorra24-browser-use/.venv/bin/python /opt/andorra24-browser-use/runway-login.py
Restart=no
NoNewPrivileges=yes
UMask=0077
UNIT
cat >/etc/systemd/system/andorra24-runway-login-vnc.service <<'UNIT'
[Unit]
Description=ANDORRA24 VNC localhost only
Requires=andorra24-runway-login-display.service
After=andorra24-runway-login-display.service
[Service]
Type=simple
User=andorra24browser
Group=andorra24browser
Environment=HOME=/var/lib/andorra24-browser-use
ExecStart=/usr/bin/x11vnc -display :99 -auth /var/lib/andorra24-browser-use/.Xauthority -localhost -rfbport 5901 -rfbauth /var/lib/andorra24-browser-use/vnc-password -forever -shared -noxdamage
Restart=on-failure
NoNewPrivileges=yes
UNIT
cat >/etc/systemd/system/andorra24-runway-login-web.service <<'UNIT'
[Unit]
Description=ANDORRA24 noVNC WebSocket localhost only (SSH tunnel)
Requires=andorra24-runway-login-vnc.service
After=andorra24-runway-login-vnc.service
[Service]
Type=simple
User=andorra24browser
Group=andorra24browser
ExecStart=/usr/bin/websockify --web=/usr/share/novnc 127.0.0.1:6080 127.0.0.1:5901
Restart=on-failure
NoNewPrivileges=yes
UNIT
# Stop any partially failed previous attempt; retain browser profile and secrets.
systemctl stop andorra24-runway-login-browser.service andorra24-runway-login-web.service andorra24-runway-login-vnc.service andorra24-runway-login-display.service >/dev/null 2>&1 || true
systemctl daemon-reload
systemctl reset-failed andorra24-runway-login-display.service andorra24-runway-login-vnc.service andorra24-runway-login-web.service andorra24-runway-login-browser.service >/dev/null 2>&1 || true
on_error() {
  echo "RUNWAY_LOGIN_SERVICE_ERROR; diagnostic excerpts (no passwords):" >&2
  systemctl --no-pager --full status andorra24-runway-login-display.service andorra24-runway-login-vnc.service andorra24-runway-login-web.service andorra24-runway-login-browser.service >&2 || true
  journalctl --no-pager -n 18 -u andorra24-runway-login-display.service -u andorra24-runway-login-vnc.service -u andorra24-runway-login-web.service -u andorra24-runway-login-browser.service >&2 || true
}
trap on_error ERR
systemctl start andorra24-runway-login-display.service
# Both Xvfb and the browser/VNC need the SAME Unix socket namespace.
for i in $(seq 1 40); do
  [[ -S /tmp/.X11-unix/X99 ]] && break
  sleep 0.25
done
[[ -S /tmp/.X11-unix/X99 ]] || { echo "Xvfb socket not ready" >&2; on_error; exit 5; }
systemctl start andorra24-runway-login-vnc.service
systemctl start andorra24-runway-login-web.service
systemctl start andorra24-runway-login-browser.service
sleep 2
systemctl is-active --quiet andorra24-runway-login-display.service
systemctl is-active --quiet andorra24-runway-login-vnc.service
systemctl is-active --quiet andorra24-runway-login-web.service
systemctl is-active --quiet andorra24-runway-login-browser.service
ss -ltn | grep -E '127[.]0[.]0[.]1:6080 ' >/dev/null
echo "RUNWAY_MANUAL_LOGIN_PORTAL_READY on $INSTANCE"
echo "VNC 127.0.0.1:6080 requires SSH tunnel; NEVER expose publicly."
echo "View VNC passphrase on VM: sudo cat /etc/andorra24-browser-use/vnc-readable-on-runner.txt; do NOT post in chat."
echo "After user signs into Runway, stop four login services to persist the profile."
echo "NOT connected to n8n; not generating or publishing."
