#!/bin/bash
# Auto-suspend GCE VM after no activity for IDLE_TIMEOUT seconds.
#
# Checks two conditions to detect idleness:
#   1. No SSH connections at all, OR
#   2. SSH connections exist but are idle (zombie browser sessions):
#      - 5-min load average < 0.1 (no CPU work)
#      - All TTYs idle for > IDLE_TIMEOUT (no user interaction)
#
# Install: see install-auto-suspend.sh

IDLE_TIMEOUT=${IDLE_TIMEOUT:-7200}  # default 2 hours
SUSPEND_RETRIES=3
SUSPEND_RETRY_DELAY=10

ZONE=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/zone | cut -d/ -f4)
INSTANCE=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/name)
PROJECT=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/project/project-id)

has_ssh_sessions() {
  ss -tnp state established '( sport = :22 )' 2>/dev/null | grep -q ssh
}

# Check if any real work is happening (CPU activity or recent user input)
is_active() {
  # Check 5-min load average — if above threshold, something is running
  local load
  load=$(awk '{print $2}' /proc/loadavg)
  if awk "BEGIN {exit !($load >= 0.1)}"; then
    return 0  # active: CPU work in progress
  fi

  # Check if any TTY has had recent activity (write within IDLE_TIMEOUT)
  local now idle_since max_idle
  now=$(date +%s)
  for pts in /dev/pts/[0-9]*; do
    idle_since=$(stat -c %Y "$pts" 2>/dev/null) || continue
    max_idle=$((now - idle_since))
    if [ "$max_idle" -lt "$IDLE_TIMEOUT" ]; then
      return 0  # active: recent TTY activity
    fi
  done

  return 1  # idle: no CPU work, all TTYs stale
}

# Suspend using direct API call (faster and more reliable than gcloud CLI).
# The VM freezes during suspend, so the calling process never gets a response.
# We use a short curl timeout and fire-and-forget with retries.
do_suspend() {
  local token
  token=$(curl -s -H "Metadata-Flavor: Google" \
    "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" \
    | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p')

  if [ -z "$token" ]; then
    echo "$(date): ERROR: Failed to get access token"
    return 1
  fi

  for i in $(seq 1 $SUSPEND_RETRIES); do
    echo "$(date): Suspend attempt $i/$SUSPEND_RETRIES..."
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 15 -X POST \
      -H "Authorization: Bearer $token" \
      -H "Content-Type: application/json" \
      "https://compute.googleapis.com/compute/v1/projects/$PROJECT/zones/$ZONE/instances/$INSTANCE/suspend")

    # 200 = success, 000 = timeout (expected — VM froze mid-request)
    if [ "$http_code" = "200" ] || [ "$http_code" = "000" ]; then
      echo "$(date): Suspend request sent (HTTP $http_code)"
      return 0
    fi

    echo "$(date): Suspend failed (HTTP $http_code), retrying in ${SUSPEND_RETRY_DELAY}s..."
    sleep $SUSPEND_RETRY_DELAY
  done

  echo "$(date): ERROR: All $SUSPEND_RETRIES suspend attempts failed"
  return 1
}

while true; do
  if has_ssh_sessions; then
    if is_active; then
      sleep 60
    else
      echo "$(date): SSH connections exist but no activity. Waiting ${IDLE_TIMEOUT}s before suspend..."
      sleep $IDLE_TIMEOUT
      if is_active; then
        echo "$(date): Activity detected, cancelling suspend."
      else
        echo "$(date): Still idle. Suspending."
        do_suspend
      fi
    fi
  else
    echo "$(date): No SSH connections. Waiting ${IDLE_TIMEOUT}s before suspend..."
    sleep $IDLE_TIMEOUT
    if ! has_ssh_sessions; then
      echo "$(date): Still no connections. Suspending."
      do_suspend
    else
      echo "$(date): Connection detected, cancelling suspend."
    fi
  fi
done
