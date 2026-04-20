#!/bin/bash
# Fix network interface after VM resume from suspend.
#
# GCE VMs sometimes lose network connectivity after suspend/resume —
# the NIC doesn't reinitialize, making the metadata server (and everything
# else) unreachable. This script bounces the interface and restarts the
# guest agent so SSH and IAP work immediately on resume.

set -euo pipefail

NIC="ens4"
METADATA_URL="http://metadata.google.internal/computeMetadata/v1/instance/zone"
MAX_WAIT=30

echo "$(date): Restarting network interface $NIC after resume..."

# Bounce the NIC
ip link set "$NIC" down
sleep 1
ip link set "$NIC" up

# Wait for DHCP lease
if command -v dhclient &>/dev/null; then
  dhclient -v "$NIC" 2>&1 || true
else
  # Debian 12+ uses systemd-networkd
  systemctl restart systemd-networkd
fi

# Wait for metadata server to become reachable
for i in $(seq 1 $MAX_WAIT); do
  if curl -sf -m 2 -H "Metadata-Flavor: Google" "$METADATA_URL" &>/dev/null; then
    echo "$(date): Metadata server reachable after ${i}s"
    break
  fi
  sleep 1
done

# Restart guest agent so it picks up the restored network
systemctl restart google-guest-agent 2>/dev/null || true

echo "$(date): Network recovery complete"
