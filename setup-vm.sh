#!/bin/bash
# Create and provision a GCE VM for running AI coding agents.
#
# Prerequisites:
#   - gcloud CLI authenticated
#   - A GCP project with billing enabled and Compute Engine API active
#
# Usage:
#   bash setup-vm.sh                          # use defaults
#   PROJECT=my-project ZONE=us-central1-a bash setup-vm.sh  # override
set -euo pipefail

# --- Configuration ---
PROJECT="${PROJECT:-my-project}"
ZONE="${ZONE:-europe-west6-a}"
INSTANCE="${INSTANCE:-ccvm}"
MACHINE_TYPE="${MACHINE_TYPE:-n2-standard-2}"
DISK_SIZE="${DISK_SIZE:-30GB}"
DISK_TYPE="${DISK_TYPE:-pd-ssd}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# ---

echo "=== Creating VM ==="
echo "Project:  $PROJECT"
echo "Zone:     $ZONE"
echo "Instance: $INSTANCE"
echo "Machine:  $MACHINE_TYPE"
echo "Disk:     $DISK_SIZE $DISK_TYPE"
echo ""

gcloud compute instances create "$INSTANCE" \
  --project="$PROJECT" \
  --zone="$ZONE" \
  --machine-type="$MACHINE_TYPE" \
  --image-family=debian-12 \
  --image-project=debian-cloud \
  --boot-disk-size="$DISK_SIZE" \
  --boot-disk-type="$DISK_TYPE" \
  --scopes=cloud-platform \
  --tags=ccvm

echo ""
echo "=== Waiting for SSH ==="
while ! gcloud compute ssh "$INSTANCE" --zone="$ZONE" --project="$PROJECT" --command='true' 2>/dev/null; do
  sleep 5
done

echo "=== Installing Node.js, tmux, and git ==="
gcloud compute ssh "$INSTANCE" --zone="$ZONE" --project="$PROJECT" --command='
  curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - && \
  sudo apt-get install -y nodejs tmux git && \
  echo "---" && \
  echo "Node.js: $(node --version)" && \
  echo "tmux: $(tmux -V)" && \
  echo "git: $(git --version)"
'

echo ""
echo "=== Copying first-run setup script ==="
gcloud compute scp \
  "$SCRIPT_DIR/first-run-setup.sh" \
  "$INSTANCE:~/first-run-setup.sh" \
  --zone="$ZONE" --project="$PROJECT"

echo ""
echo "=== Installing auto-suspend ==="
gcloud compute scp \
  "$SCRIPT_DIR/auto-suspend/auto-suspend.sh" \
  "$SCRIPT_DIR/auto-suspend/auto-suspend.service" \
  "$SCRIPT_DIR/auto-suspend/install-auto-suspend.sh" \
  "$INSTANCE:/tmp/" \
  --zone="$ZONE" --project="$PROJECT"

gcloud compute ssh "$INSTANCE" --zone="$ZONE" --project="$PROJECT" --command='bash /tmp/install-auto-suspend.sh'

echo ""
echo "=== Setup complete ==="
echo "Connect with: ccvm"
echo "On first connect, you'll be prompted to set up your AI agents and sign in."
