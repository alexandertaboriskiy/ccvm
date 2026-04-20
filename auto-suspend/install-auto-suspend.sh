#!/bin/bash
# Install auto-suspend service on a GCE VM.
# Run this ON the VM (e.g. via gcloud compute ssh).
#
# Usage:
#   bash install-auto-suspend.sh           # default 6 hour timeout
#   IDLE_TIMEOUT=3600 bash install-auto-suspend.sh  # 1 hour timeout
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TIMEOUT="${IDLE_TIMEOUT:-21600}"

sudo cp "$SCRIPT_DIR/auto-suspend.sh" /usr/local/bin/auto-suspend.sh
sudo chmod +x /usr/local/bin/auto-suspend.sh

sudo cp "$SCRIPT_DIR/auto-suspend.service" /etc/systemd/system/auto-suspend.service
sudo sed -i "s/IDLE_TIMEOUT=21600/IDLE_TIMEOUT=$TIMEOUT/" /etc/systemd/system/auto-suspend.service

sudo cp "$SCRIPT_DIR/fix-network-on-resume.sh" /usr/local/bin/fix-network-on-resume.sh
sudo chmod +x /usr/local/bin/fix-network-on-resume.sh

sudo cp "$SCRIPT_DIR/fix-network-on-resume.service" /etc/systemd/system/fix-network-on-resume.service

sudo cp "$SCRIPT_DIR/network-watchdog.sh" /usr/local/bin/network-watchdog.sh
sudo chmod +x /usr/local/bin/network-watchdog.sh

sudo cp "$SCRIPT_DIR/network-watchdog.service" /etc/systemd/system/network-watchdog.service

sudo systemctl daemon-reload
sudo systemctl enable auto-suspend network-watchdog fix-network-on-resume
sudo systemctl start auto-suspend network-watchdog

echo "Auto-suspend installed. Timeout: ${TIMEOUT}s"
echo "Fix-network-on-resume installed."
sudo systemctl status auto-suspend --no-pager
echo ""
echo "Network watchdog installed."
sudo systemctl status network-watchdog --no-pager
