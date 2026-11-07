#!/usr/bin/env bash
set -Eeuo pipefail
PROJECT=andorra-24-live
ZONE=us-central1-c
VM=andorra24-runway-runner
command -v gcloud >/dev/null || { echo "Run in Cloud Shell"; exit 1; }
remote="sudo systemctl stop andorra24-runway-login-browser.service; sudo systemctl stop andorra24-runway-login-web.service andorra24-runway-login-vnc.service andorra24-runway-login-display.service; sudo test -d /var/lib/andorra24-browser-use/runway-profile/Default && echo RUNWAY_PROFILE_PERSISTED; sudo systemctl is-active andorra24-browser-preflight.timer"
gcloud compute ssh "$VM" --project "$PROJECT" --zone "$ZONE" --command "$remote"
echo "Profile retained on runner. Session authentication MUST be validated before any automated generation."
