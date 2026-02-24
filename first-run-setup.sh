#!/bin/bash
# First-run setup for ccvm. Installs AI coding agents and configures authentication.
# Runs interactively on the VM on first connect.
set -euo pipefail

SETUP_MARKER="$HOME/.ccvm-setup-done"

if [ -f "$SETUP_MARKER" ]; then
  echo "Setup already completed. Delete $SETUP_MARKER to re-run."
  exit 0
fi

echo "==============================="
echo "  ccvm - first time setup"
echo "==============================="
echo ""

# Check if Node.js is installed
if ! command -v node &>/dev/null; then
  echo "Installing Node.js 22..."
  curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
  sudo apt-get install -y nodejs
fi

# Check if tmux is installed
if ! command -v tmux &>/dev/null; then
  echo "Installing tmux..."
  sudo apt-get install -y tmux
fi

echo ""
echo "Which agents do you want to set up?"
echo "  1) Claude Code only"
echo "  2) Gemini CLI only"
echo "  3) Both"
echo ""
read -p "Choice [3]: " AGENT_CHOICE
AGENT_CHOICE="${AGENT_CHOICE:-3}"

SETUP_CLAUDE=false
SETUP_GEMINI=false

case "$AGENT_CHOICE" in
  1) SETUP_CLAUDE=true ;;
  2) SETUP_GEMINI=true ;;
  3) SETUP_CLAUDE=true; SETUP_GEMINI=true ;;
  *) echo "Invalid choice."; exit 1 ;;
esac

# --- Gemini CLI ---
if [ "$SETUP_GEMINI" = true ]; then
  echo ""
  echo "--- Gemini CLI ---"

  if ! command -v gemini &>/dev/null; then
    echo "Installing Gemini CLI..."
    sudo npm install -g @google/gemini-cli
  else
    echo "Gemini CLI already installed: $(gemini --version)"
  fi

  echo ""
  echo "Gemini CLI will prompt you to sign in on first use (ccvm --project --env=gemini)."
fi

# --- Claude Code ---
if [ "$SETUP_CLAUDE" = true ]; then
  echo ""
  echo "--- Claude Code ---"

  if ! command -v claude &>/dev/null; then
    echo "Installing Claude Code..."
    sudo npm install -g @anthropic-ai/claude-code
  else
    echo "Claude Code already installed: $(claude --version)"
  fi

  echo ""
  echo "Claude Code will prompt you to sign in on first use (ccvm --project)."
fi

# Mark setup as done
echo ""
echo "--- Installed agents ---"
command -v claude &>/dev/null && echo "  Claude Code: $(claude --version)"
command -v gemini &>/dev/null && echo "  Gemini CLI:  $(gemini --version)"

date > "$SETUP_MARKER"
echo ""
echo "Setup complete! You can re-run this anytime by deleting ~/.ccvm-setup-done"
