# tlmgr — Development Context

Always read `PLAN.md` first for current priorities.

## Project Structure

```
tlmgr/
├── bin/tlmgr              # Entry point (~80 lines): path resolution, module loading, dispatch
├── lib/
│   ├── output.sh          # Colors, header/error/info/warning helpers, git_safe, rel_path
│   ├── json.sh            # json_escape, json_object, HAS_JQ detection, JSON_OUTPUT flag
│   └── commands.sh        # All cmd_* functions, get_tools, for_each_tool
├── data/
│   ├── completion.bash    # Bash completion for tlmgr
│   └── repos.conf.default # Default config template
├── install.sh             # Symlink + completion + config init
├── PLAN.md                # Development plan (tickbox tracking)
├── VERSION                # Current version string
└── .gitignore
```

## Key Design Decisions

### Path Resolution

All paths derived at runtime via `readlink -f`. No hardcoded paths:

```bash
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"          # resolved binary
TLMGR_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"  # tlmgr project root
TOOLS_ROOT="${TOOLS_ROOT:-$(dirname "$TLMGR_ROOT")}"       # parent tools dir
```

`TOOLS_ROOT` env var override supported. Validated by checking `$TOOLS_ROOT/.git`.

### Config Location

`~/.config/tlmgr/repos.conf` (XDG-compliant via `$XDG_CONFIG_HOME`). Auto-initialized from `data/repos.conf.default` on first use.

### Module Architecture

`bin/tlmgr` sources three modules in order:
1. `lib/output.sh` — no dependencies
2. `lib/json.sh` — no dependencies
3. `lib/commands.sh` — depends on output.sh and json.sh globals

All modules share global variables: `TOOLS_ROOT`, `TLMGR_ROOT`, `CONFIG_DIR`, `REPOS_CONF`, `TLMGR_VERSION`, `JSON_OUTPUT`.

## Adding a New Subcommand

1. Add `cmd_foo()` function to `lib/commands.sh`
2. Add case in `bin/tlmgr` dispatch (with alias if desired)
3. If JSON-capable, add to `json_commands` array in `bin/tlmgr`
4. Update `cmd_help()` in `lib/commands.sh`
5. Update `data/completion.bash` subcommands list
6. Update `README.md` command reference

## Testing

Manual verification (no automated test suite yet):

```bash
tlmgr list                    # All repos with status
tlmgr --json list | jq '.[0]' # Valid JSON
tlmgr summary                 # Counts match expectations
tlmgr --json summary          # Valid JSON
tlmgr changes                 # Cross-check with git status
tlmgr config                  # Correct paths
tlmgr version                 # Matches VERSION file
tlmgr bootstrap               # Skips existing, reports counts
tlmgr completion bash          # Valid bash script
source <(tlmgr completion bash) && tlmgr <TAB>  # Completion works
```

## Arithmetic Under set -e

Guard `((var++))` with `|| true` when var may be 0. See parent CLAUDE.md for details.

## Progress Tracking Protocol

When modifying `PLAN.md`:
- `[ ]` → `[-]` when starting work (add date: YYYY-MM-DD)
- `[-]` → `[x]` when complete (add date: YYYY-MM-DD)
- Move completed items to Archive section periodically
