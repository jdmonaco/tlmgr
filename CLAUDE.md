# tlmgr — Development Context

Current priorities: @PLAN.md

## Project Structure

```
tlmgr/
├── bin/tlmgr              # Entry point (~80 lines): path resolution, module loading, dispatch
├── lib/
│   ├── output.sh          # Colors, header/error/info/warning helpers, git_safe, rel_path
│   ├── json.sh            # json_escape, json_object, HAS_JQ detection, JSON_OUTPUT flag
│   ├── toml.sh            # toml_get_value, toml_array_contains, toml_get_section_pairs
│   └── commands.sh        # All cmd_* functions, get_tools, for_each_tool
├── data/
│   ├── completion.bash    # Bash completion for tlmgr
│   └── repos.conf.default # Default config template (generic examples)
├── install.sh             # Symlink + completion + config init
├── PLAN.md                # Development plan (tickbox tracking)
├── VERSION                # Current version string
├── LICENSE                # MIT license
└── .gitignore
```

## Key Design Decisions

### Path Resolution

All paths derived at runtime via `readlink -f`. No hardcoded paths:

```bash
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"          # resolved binary
TLMGR_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"  # tlmgr project root
TOOLS_ROOT="${TOOLS_ROOT:-$(dirname "$TLMGR_ROOT")}"       # parent directory
```

`TOOLS_ROOT` defaults to the parent of tlmgr's directory. Override with the `TOOLS_ROOT` env var to manage repos in a different location.

### Config Location

`~/.config/tlmgr/repos.conf` (XDG-compliant via `$XDG_CONFIG_HOME`). Auto-initialized from `data/repos.conf.default` on first use of `tlmgr bootstrap`.

### Module Architecture

`bin/tlmgr` sources four modules in order:
1. `lib/output.sh` — no dependencies
2. `lib/json.sh` — no dependencies
3. `lib/toml.sh` — no dependencies
4. `lib/commands.sh` — depends on output.sh, json.sh, and toml.sh globals

All modules share global variables: `TOOLS_ROOT`, `TLMGR_ROOT`, `CONFIG_DIR`, `REPOS_CONF`, `TLMGR_VERSION`, `JSON_OUTPUT`.

### Repo Discovery

`get_tools()` in `lib/commands.sh` finds repos by scanning for `.git` directories under `TOOLS_ROOT` (up to 3 levels deep). It skips `TOOLS_ROOT` itself if it happens to be a git repo. This means tlmgr works whether or not the parent directory is a git repository.

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
tlmgr versions                # All tools with version + source
tlmgr --json versions         # Valid JSON array
tlmgr commands                # All CLI entrypoints grouped by tool
tlmgr --json commands         # Valid JSON array
tlmgr bootstrap               # Skips existing, reports counts
tlmgr completion bash          # Valid bash script
source <(tlmgr completion bash) && tlmgr <TAB>  # Completion works
```

## Arithmetic Under set -e

Guard `((var++))` with `|| true` when var may be 0. `((0))` evaluates as falsy in bash and triggers `set -e` to exit.

## Progress Tracking Protocol

When modifying `PLAN.md`:
- `[ ]` → `[-]` when starting work (add date: YYYY-MM-DD)
- `[-]` → `[x]` when complete (add date: YYYY-MM-DD)
- Move completed items to Archive section periodically
