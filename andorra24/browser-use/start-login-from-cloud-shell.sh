#!/usr/bin/env bash
# Run only in authenticated Google Cloud Shell. Opens one-time secure Runway login.
set -Eeuo pipefail
PROJECT=andorra-24-live
ZONE=us-central1-c
VM=andorra24-runway-runner
REF=b347ad88233e45323433b195f916fdb0ef3ed703
ROOT=https://raw.githubusercontent.com/josepguirao/hal9000
command -v gcloud >/dev/null || { echo "BLOCKED: needs Google Cloud Shell" >&2; exit 2; }
[[ -n "$(gcloud auth list --filter=status:ACTIVE --format='value(account)' | head -n1)" ]] || { echo "BLOCKED: Google login required" >&2; exit 2; }
[[ "$(gcloud compute instances describe "$VM" --project "$PROJECT" --zone "$ZONE" --format='value(status)')" == "RUNNING" ]] || { echo "BLOCKED: existing runner VM not running" >&2; exit 3; }
echo "Connecting to existing ANDORRA 24 runner; LIVE untouched."
remote="set -eu; curl -fsSL '$ROOT/$REF/andorra24/browser-use/setup-manual-runway-login.sh' -o /tmp/andorra24-runway-login-setup.sh; sudo bash /tmp/andorra24-runway-login-setup.sh"
gcloud compute ssh "$VM" --project "$PROJECT" --zone "$ZONE" --command "$remote"
echo
echo "Runway login portal installed. VNC password (not a Runway credential):"
gcloud compute ssh "$VM" --project "$PROJECT" --zone "$ZONE" --command "sudo cat /etc/andorra24-browser-use/vnc-readable-on-runner.txt"
echo
echo "NEXT: In Cloud Shell, choose 'Web Preview' -> Change port -> 6080 -> Preview."
echo "Enter the VNC password shown above, then sign into your own Runway account."
echo "After login, close this SSH session with Ctrl+C and close the Runway browser gracefully using the finishing command in GitHub README."
echo "Starting SSH loopback tunnel. Keep THIS TERMINAL open during login."
gcloud compute ssh "$VM" --project "$PROJECT" --zone "$ZONE" -- -N -L 127.0.0.1:6080:127.0.0.1:6080
