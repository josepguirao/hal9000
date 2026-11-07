#!/usr/bin/env bash
# One-shot authorized Cloud Shell deployment. Never targets LIVE.
set -Eeuo pipefail
PROJECT=andorra-24-live
ZONE=us-central1-c
VM=andorra24-runway-runner
command -v gcloud >/dev/null || { echo 'Use Google Cloud Shell' >&2; exit 2; }
[[ -n "$(gcloud auth list --filter=status:ACTIVE --format='value(account)' | head -n 1)" ]] || { echo 'Google login required' >&2; exit 2; }
[[ "$(gcloud compute instances describe "$VM" --project "$PROJECT" --zone "$ZONE" --format='value(status)')" == 'RUNNING' ]] || { echo 'VM not running' >&2; exit 3; }
remote=$(cat <<'REMOTE'
set -eu
D=$(mktemp -d)
trap 'rm -rf "$D"' EXIT
curl -fsSL 'https://raw.githubusercontent.com/josepguirao/hal9000/1f064b337c4ce92dcb02e70bf6e2b07c77f65096/andorra24/browser-use/bridge.py' -o "$D/bridge.py"
curl -fsSL 'https://raw.githubusercontent.com/josepguirao/hal9000/1f064b337c4ce92dcb02e70bf6e2b07c77f65096/andorra24/browser-use/install-bridge.sh' -o "$D/install.sh"
sudo bash "$D/install.sh" "$D/bridge.py"
REMOTE
)
gcloud compute ssh "$VM" --project "$PROJECT" --zone "$ZONE" --command "$remote"
echo 'BRIDGE_BOOTSTRAP_COMPLETE. To connect n8n configure protected webhooks and token.'
