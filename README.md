# tlmgr

A lightweight CLI for managing collections of git repositories under a shared parent directory.

tlmgr discovers git repos in a workspace, reports their status at a glance, and provides bulk operations (fetch, pull, exec) across all of them. Designed for developers who maintain many related projects — tool collections, microservices, monorepo alternatives — without the overhead of git submodules.

## Installation

```bash
git clone <tlmgr-repo-url> /path/to/your/workspace/tlmgr
cd /path/to/your/workspace/tlmgr
./install.sh
```

`install.sh` creates:
- `~/.local/bin/tlmgr` symlink
- `~/.local/share/bash-completion/completions/tlmgr` completion file
- `~/.config/tlmgr/repos.conf` config (from default template, if missing)

Ensure `~/.local/bin` is in your `$PATH`.

## How It Works

tlmgr treats its **parent directory** as the workspace root (`TOOLS_ROOT`). It discovers all git repositories under that directory automatically — no registration required for existing repos.

```
workspace/            # <- TOOLS_ROOT (auto-detected)
├── tlmgr/            # <- tlmgr lives here
├── project-a/        # <- discovered automatically
├── project-b/        # <- discovered automatically
└── project-c/        # <- discovered automatically
```

To manage repos in a different location, set the `TOOLS_ROOT` environment variable:

```bash
export TOOLS_ROOT=/path/to/repos
tlmgr list
```

The workspace directory does **not** need to be a git repository itself.

## Configuration

Config lives at `~/.config/tlmgr/` (respects `$XDG_CONFIG_HOME`):

```
~/.config/tlmgr/
└── repos.conf          # Machine-specific repo list for bootstrap
```

The `repos.conf` file is only used by `tlmgr bootstrap` to clone repos that don't exist yet. All other commands discover repos by scanning the filesystem.

Edit `repos.conf` to list your repositories:

```conf
# Format: <name> <git-url>

# SSH (GitHub)
myproject   git@github.com:user/myproject.git

# HTTPS (GitLab)
webapp      https://gitlab.com/user/webapp.git

# SSH (self-hosted, custom port)
infra       ssh://git@git.example.com:2222/user/infra.git

# Local path
shared-lib  /home/user/repos/shared-lib.git
```

Then run `tlmgr bootstrap` to clone them all.

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

## License

MIT
