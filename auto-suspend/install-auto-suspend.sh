#!/bin/bash
# Install auto-suspend service on a GCE VM.
# Run this ON the VM (e.g. via gcloud compute ssh).
#
# Usage:
#   bash install-auto-suspend.sh           # default 2 hour timeout
#   IDLE_TIMEOUT=3600 bash install-auto-suspend.sh  # 1 hour timeout
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TIMEOUT="${IDLE_TIMEOUT:-7200}"

sudo cp "$SCRIPT_DIR/auto-suspend.sh" /usr/local/bin/auto-suspend.sh
sudo chmod +x /usr/local/bin/auto-suspend.sh

sudo cp "$SCRIPT_DIR/auto-suspend.service" /etc/systemd/system/auto-suspend.service
sudo sed -i "s/IDLE_TIMEOUT=7200/IDLE_TIMEOUT=$TIMEOUT/" /etc/systemd/system/auto-suspend.service

sudo systemctl daemon-reload
sudo systemctl enable auto-suspend
sudo systemctl start auto-suspend

echo "Auto-suspend installed. Timeout: ${TIMEOUT}s"
sudo systemctl status auto-suspend --no-pager
