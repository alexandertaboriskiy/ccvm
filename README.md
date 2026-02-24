# ccvm - Cloud Code VM

Run AI coding agents (Claude Code, Gemini CLI) on a GCE VM that auto-suspends when idle and resumes on connect. One command to go from suspended VM to your agent running in your project.

## Why

- **Persistent sessions** — your agent keeps running in tmux even when you disconnect
- **Suspend/resume** — VM saves full memory state to disk when idle, resumes in seconds. You only pay for compute when connected.
- **One command** — `ccvm --my-project` handles everything: resume VM, SSH, tmux, start agent
- **Multi-agent** — switch between Claude Code and Gemini CLI with `--env=claude` or `--env=gemini`
- **Cost control** — budget alerts notify you before spending gets out of hand

## Quick start

### 1. Create the VM

```bash
PROJECT=my-project ZONE=europe-west6-a bash setup-vm.sh
```

This creates an n2-standard-2 VM with Node.js, tmux, and auto-suspend installed.

### 2. Install the connect script

```bash
cp ccvm ~/bin/ccvm
chmod +x ~/bin/ccvm
```

Edit the configuration variables at the top of `ccvm` to match your setup.

### 3. Set up budget alerts (optional)

```bash
PROJECT=my-project BUDGET=30 EMAIL=you@example.com bash setup-budget-alert.sh
```

### 4. Connect

```bash
# First connect — installs your chosen agents
ccvm

# Open Claude Code in a project
ccvm --my-project

# Open Gemini CLI in a project
ccvm --my-project --env=gemini

# List projects and active sessions
ccvm ls

# Delete projects
ccvm --delete=old-project
ccvm --delete=proj1,proj2,proj3
```

On first connect, you'll be prompted to choose which agents to install. Each agent handles sign-in on first use. Run the same command again later to reattach to the same session.

## How it works

```
ccvm                              ccvm --my-project --env=claude
  │                                 │
  ├─ Resume/start VM if needed      ├─ Resume/start VM if needed
  │                                 │
  ├─ First run? → install agents    ├─ Create ~/cloud-projects/my-project/
  └─ Land in ~/cloud-projects/      ├─ Create tmux session "my-project"
                                    ├─ Start Claude Code in the session
                                    └─ Attach to tmux session
```

After you disconnect, the auto-suspend service waits 2 hours (configurable) with no SSH connections, then suspends the VM. Suspended VMs preserve full memory state and cost only disk storage (~$1-2/month).

## Components

| File | Where it runs | What it does |
|---|---|---|
| `ccvm` | Your local machine | Resume VM + SSH + tmux + start agent |
| `first-run-setup.sh` | On the VM | Interactive agent install on first connect |
| `auto-suspend/` | On the VM | Suspend VM after idle timeout |
| `setup-vm.sh` | Local (uses gcloud) | Create and provision the VM |
| `setup-budget-alert.sh` | Local (uses gcloud) | Set up email budget alerts |

## Configuration

### ccvm

Edit the variables at the top of the script:

```bash
PROJECT="my-gcp-project"
ZONE="europe-west6-a"
INSTANCE="ccvm"
PROJECTS_DIR="cloud-projects"

DEFAULT_ENV="claude"
CLAUDE_CMD="claude --dangerously-skip-permissions --model opus"
GEMINI_CMD="gemini --yolo --model gemini-2.5-pro"
```

### Auto-suspend timeout

Change the timeout in the systemd service:

```bash
# On the VM
sudo sed -i 's/IDLE_TIMEOUT=7200/IDLE_TIMEOUT=3600/' /etc/systemd/system/auto-suspend.service
sudo systemctl daemon-reload
sudo systemctl restart auto-suspend
```

### VM machine type

The VM size barely affects agent response speed since inference happens on the provider's servers. A small VM works fine for coding tasks. Use a larger machine if you run builds or tests.

| Use case | Machine type | Cost/month |
|---|---|---|
| Coding only | e2-small (2 GB) | ~$15 |
| Coding + builds | n2-standard-2 (8 GB) | ~$55 |

## Supported agents

| Agent | Flag | Install |
|---|---|---|
| [Claude Code](https://github.com/anthropics/claude-code) | `--env=claude` (default) | `npm i -g @anthropic-ai/claude-code` |
| [Gemini CLI](https://github.com/google-gemini/gemini-cli) | `--env=gemini` | `npm i -g @google/gemini-cli` |

## Cost

- **Running**: ~$0.07/hr for n2-standard-2 in europe-west6
- **Suspended**: ~$1-2/month (disk storage only)
- **Resumed**: full memory state restored in ~30 seconds
- Suspended VMs auto-terminate after 60 days (GCP limit)

## Requirements

- `gcloud` CLI installed and authenticated
- A GCP project with billing enabled
- A subscription or API key for your chosen agent
