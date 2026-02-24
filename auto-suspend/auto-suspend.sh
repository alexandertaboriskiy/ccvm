#!/bin/bash
# Auto-suspend GCE VM after no SSH connections for IDLE_TIMEOUT seconds.
# Uses TCP connection check (ss) instead of `who` to avoid stale ptty issues.
#
# Install: see install-auto-suspend.sh

IDLE_TIMEOUT=${IDLE_TIMEOUT:-7200}  # default 2 hours
ZONE=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/zone | cut -d/ -f4)
INSTANCE=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/name)

has_ssh_sessions() {
  ss -tnp state established '( sport = :22 )' 2>/dev/null | grep -q ssh
}

while true; do
  if has_ssh_sessions; then
    sleep 60
  else
    echo "$(date): No SSH connections. Waiting ${IDLE_TIMEOUT}s before suspend..."
    sleep $IDLE_TIMEOUT
    if ! has_ssh_sessions; then
      echo "$(date): Still no connections. Suspending."
      gcloud compute instances suspend "$INSTANCE" --zone="$ZONE" --quiet
    else
      echo "$(date): Connection detected, cancelling suspend."
    fi
  fi
done
