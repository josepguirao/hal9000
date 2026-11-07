#!/usr/bin/env bash
# One-shot entrypoint from authenticated Google Cloud Shell.
set -Eeuo pipefail
PROJECT=andorra-24-live
ZONE=us-central1-c
VM=andorra24-runway-runner
REF=407904ae1f4505212e2d186292fcc4eb0aceb895
ROOT="https://raw.githubusercontent.com/josepguirao/hal9000/$REF/andorra24/browser-use"
command -v gcloud >/dev/null || { echo "BLOCKED: open this script in Google Cloud Shell, not locally" >&2; exit 3; }
active_user="$(gcloud auth list --filter=status:ACTIVE --format='value(account)' | head -n1)"
[[ -n "$active_user" ]] || { echo "BLOCKED: GCP identity not authenticated" >&2; exit 3; }
echo "GCP account: $active_user"
status="$(gcloud compute instances describe "$VM" --project "$PROJECT" --zone "$ZONE" --format='value(status)')"
[[ "$status" == "RUNNING" ]] || { echo "BLOCKED: $VM is $status; refusing to create/start VM" >&2; exit 4; }
echo "EXISTING RUNNER VERIFIED: $PROJECT/$ZONE/$VM is RUNNING"
# No Live changes, no new VM, no Runway charge.
remote="set -eu; D=\$(mktemp -d); trap 'rm -rf \"\$D\"' EXIT; curl -fsSLo \"\$D/install.sh\" '$ROOT/install.sh'; curl -fsSLo \"\$D/preflight.py\" '$ROOT/preflight.py'; sudo bash \"\$D/install.sh\"; sudo systemctl status andorra24-browser-preflight.timer --no-pager --lines=3; sudo journalctl -u andorra24-browser-preflight.service -n 12 --no-pager"
gcloud compute ssh "$VM" --project "$PROJECT" --zone "$ZONE" --command "$remote"
echo "BOOTSTRAP COMPLETED. This only installs dependencies; Runway Web login and n8n bridge must be separately verified."
