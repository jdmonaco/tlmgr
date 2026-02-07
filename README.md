# tlmgr

Tools manager for multi-repo workspaces. Manages all tool repositories under a shared parent directory.

## Installation

```bash
cd ~/tools/tlmgr
./install.sh          # Symlink + completion + config init
tlmgr bootstrap       # Clone all repos from config
```

`install.sh` creates:
- `~/.local/bin/tlmgr` symlink
- `~/.local/share/bash-completion/completions/tlmgr` completion file
- `~/.config/tlmgr/repos.conf` config (from default template, if missing)

## Commands

### Repository Overview

```bash
tlmgr                     # List all repos with status (default)
tlmgr list                # Same as above
tlmgr summary             # Summary statistics
tlmgr branches            # Show current branch for all repos
```

### Change Detection

```bash
tlmgr changes             # Show repos with uncommitted changes
tlmgr unpushed            # Show repos with unpushed commits
tlmgr untracked           # Show repos with untracked files
```

### Operations

```bash
tlmgr status              # Full git status for all repos
tlmgr pull                # Pull (with rebase) all repos
tlmgr fetch               # Fetch all remotes for all repos
tlmgr clone <url> [name]  # Clone a new repo
tlmgr exec "command"      # Run command in all repo directories
tlmgr bootstrap           # Clone all repos from config
```

### Meta

```bash
tlmgr version             # Show version
tlmgr config              # Show configuration paths
tlmgr completion bash     # Print completion script to stdout
tlmgr help                # Show help
```

### Aliases

| Alias | Command |
|-------|---------|
| `ls` | `list` |
| `br` | `branches` |
| `ch` | `changes` |
| `up` | `unpushed` |
| `ut` | `untracked` |
| `st` | `status` |
| `boot` | `bootstrap` |
| `cfg` | `config` |

## JSON Output

All read-only commands support `--json` for programmatic use:

```bash
tlmgr --json list
tlmgr --json summary
tlmgr --json list | jq '.[] | select(.is_clean == false)'
tlmgr --json list | jq '.[] | select(.unpushed_commits > 0)'
tlmgr --json branches | jq '.[] | select(.upstream == null)'
```

## Configuration

Config lives at `~/.config/tlmgr/` (respects `$XDG_CONFIG_HOME`):

```
~/.config/tlmgr/
└── repos.conf          # Machine-specific repo list
```

On first invocation, if `repos.conf` is missing, tlmgr copies the default template from `data/repos.conf.default`.

Edit `repos.conf` to customize which repos are cloned by `tlmgr bootstrap`:

```
# Format: <name> <git-url>
myproject  git@github.com:user/myproject.git
```

## Bash Completion

Installed automatically by `./install.sh`. To manage manually:

```bash
tlmgr completion bash              # Print to stdout
tlmgr completion bash --install    # Install to standard location
tlmgr completion bash --path       # Print source file path
source <(tlmgr completion bash)    # Load for current session
```

## Status Legend

| Symbol | Meaning |
|--------|---------|
| `✓` (green) | Clean — no changes |
| `M` (yellow) | Modified — uncommitted changes |
| `↑N` (cyan) | Unpushed — N commits not pushed |
| `?` (red) | Untracked — untracked files present |
