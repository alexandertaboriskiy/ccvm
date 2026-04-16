#!/bin/bash
# Network watchdog for GCE VMs that use suspend/resume.
#
# After resuming from suspend, the network interface sometimes fails to
# come back up. This script detects that state by pinging the metadata
# server and reboots the VM if the network is unreachable for too long.
#
# To avoid false positives on normal resume (where the network just needs
# a moment), we wait GRACE_PERIOD seconds after boot before monitoring,
# and require MAX_FAILS consecutive failures before acting.
#
# Install: see install-auto-suspend.sh

GRACE_PERIOD=120     # seconds after boot before we start monitoring
CHECK_INTERVAL=30    # seconds between checks
MAX_FAILS=6          # reboot after this many consecutive failures (~3 min)
METADATA_URL="http://169.254.169.254/computeMetadata/v1/"

# Wait for grace period — gives the network time to come up after normal resume
uptime_secs=$(awk '{print int($1)}' /proc/uptime)
if [ "$uptime_secs" -lt "$GRACE_PERIOD" ]; then
  remaining=$((GRACE_PERIOD - uptime_secs))
  echo "$(date): Boot detected. Waiting ${remaining}s grace period before monitoring..."
  sleep "$remaining"
fi

# After grace period, check if network ever came up. If not, go straight to recovery.
if ! curl -sf --max-time 5 -H "Metadata-Flavor: Google" "$METADATA_URL" -o /dev/null 2>/dev/null; then
  echo "$(date): Network still down after grace period. Attempting recovery..."
  systemctl restart systemd-networkd 2>/dev/null || true
  sleep 15
  if ! curl -sf --max-time 5 -H "Metadata-Flavor: Google" "$METADATA_URL" -o /dev/null 2>/dev/null; then
    echo "$(date): Network restart didn't help. Rebooting VM."
    reboot
  fi
  echo "$(date): Network restart fixed it."
fi

# Steady-state monitoring
fail_count=0

while true; do
  sleep $CHECK_INTERVAL

  if curl -sf --max-time 5 -H "Metadata-Flavor: Google" "$METADATA_URL" -o /dev/null 2>/dev/null; then
    if [ "$fail_count" -gt 0 ]; then
      echo "$(date): Network recovered after $fail_count failures."
    fi
    fail_count=0
  else
    fail_count=$((fail_count + 1))
    echo "$(date): Metadata server unreachable ($fail_count/$MAX_FAILS)"

    if [ "$fail_count" -ge "$MAX_FAILS" ]; then
      echo "$(date): Network down for $((fail_count * CHECK_INTERVAL))s. Attempting recovery..."
      systemctl restart systemd-networkd 2>/dev/null || true
      sleep 15
      if ! curl -sf --max-time 5 -H "Metadata-Flavor: Google" "$METADATA_URL" -o /dev/null 2>/dev/null; then
        echo "$(date): Network restart didn't help. Rebooting VM."
        reboot
      else
        echo "$(date): Network restart fixed it."
        fail_count=0
      fi
    fi
  fi
done
