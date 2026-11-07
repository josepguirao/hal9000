#!/usr/bin/env bash
# From authenticated Cloud Shell: deploy the secure n8n bridge to existing runner.
set -Eeuo pipefail
PROJECT=andorra-24-live
ZONE=us-central1-c
VM=andorra24-runway-runner
REF=1f064b337c4ce92dcb02e70bf6e2b07c77f65096
ROOT=https://raw.githubusercontent.com/josepguirao/hal9000
command -v gcloud >/dev/null || { echo "Must run inside Google Cloud Shell" >&2; exit 2; }
[[ -n "$(gcloud auth list --filter=status:ACTIVE --format='value(account)' | head -n1)" ]] || { echo "Google Cloud authentication missing" >&2; exit 2; }
[[ "$(gcloud compute instances describe "$VM" --project "$PROJECT" --zone "$ZONE" --format='value(status)')" == RUNNING ]] || { echo "Existing runner is not running" >&2; exit 3; }
remote="set -eu; D=\\$(mktemp -d); trap 'rm -rf \\\"\\$D\\\"' EXIT; curl -fsSL '$ROOT/$REF/andorra24/browser-use/bridge.py' -o \\\"\\$D/bridge.py\\\"; curl -fsSL '$ROOT/$REF/andorra24/browser-use/install-bridge.sh' -o \\\"\\$D/install.sh\\\"; sudo bash \\\"\\$D/install.sh\\\" \\\"\\$D/bridge.py\\\""
gcloud compute ssh "$VM" --project "$PROJECT" --zone "$ZONE" --command "$remote"
echo "BRIDGE_BOOTSTRAP_COMPLETE: diagnostic only. n8n webhooks still need validated credentials."
