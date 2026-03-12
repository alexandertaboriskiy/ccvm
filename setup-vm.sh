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
REGION="${ZONE%-*}"
# ---

echo "=== Setting up Cloud NAT (outbound internet without external IP) ==="
if ! gcloud compute routers describe ccvm-router --region="$REGION" --project="$PROJECT" &>/dev/null; then
  gcloud compute routers create ccvm-router \
    --project="$PROJECT" \
    --region="$REGION" \
    --network=default
  gcloud compute routers nats create ccvm-nat \
    --project="$PROJECT" \
    --router=ccvm-router \
    --region="$REGION" \
    --auto-allocate-nat-external-ips \
    --nat-all-subnet-ip-ranges
else
  echo "Cloud NAT already configured, skipping."
fi

echo ""
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
  --tags=ccvm \
  --no-address

echo ""
echo "=== Waiting for SSH ==="
while ! gcloud compute ssh "$INSTANCE" --zone="$ZONE" --project="$PROJECT" --command='true' 2>/dev/null; do
  sleep 5
done

echo "=== Installing Node.js, tmux, and git ==="
gcloud compute ssh "$INSTANCE" --zone="$ZONE" --project="$PROJECT" --command='
  curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - && \
  sudo apt-get install -y nodejs tmux git && \
  sudo sed -i "/^#ClientAliveInterval/c\ClientAliveInterval 60" /etc/ssh/sshd_config && \
  sudo sed -i "/^#ClientAliveCountMax/c\ClientAliveCountMax 3" /etc/ssh/sshd_config && \
  sudo systemctl restart sshd && \
  echo "---" && \
  echo "Node.js: $(node --version)" && \
  echo "tmux: $(tmux -V)" && \
  echo "git: $(git --version)" && \
  printf "set -g mouse on\nset -s set-clipboard on\nset -g allow-passthrough on\nset -ga update-environment \"TERM_PROGRAM TERM_PROGRAM_VERSION ITERM_SESSION_ID\"\nbind-key -n C-d detach-client\n" > ~/.tmux.conf && \
  curl -sL https://iterm2.com/shell_integration/bash -o ~/.iterm2_shell_integration.bash && \
  printf "\n# iTerm2 shell integration (works through tmux)\nexport ITERM_ENABLE_SHELL_INTEGRATION_WITH_TMUX=Yes\nexport TERM_PROGRAM=iTerm.app\nif [ -f ~/.iterm2_shell_integration.bash ]; then\n  source ~/.iterm2_shell_integration.bash\nfi\n\n# Fix iTerm2 escape sequences inside tmux: wrap in DCS passthrough\n# so they reach iTerm2 through tmux instead of being silently discarded.\nif [ -n \"\\\$TMUX\" ] && declare -f iterm2_begin_osc > /dev/null 2>&1; then\n  iterm2_begin_osc() { printf \"\\\\\\\\ePtmux;\\\\\\\\e\\\\\\\\e]\"; }\n  iterm2_end_osc() { printf \"\\\\\\\\a\\\\\\\\e\\\\\\\\\\\\\\\\\"; }\nfi\n" >> ~/.bashrc
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
