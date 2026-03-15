# lib/commands.sh — All tlmgr subcommand implementations
# Sourced by bin/tlmgr
# Depends on: lib/output.sh, lib/json.sh, lib/toml.sh
# Expects: TOOLS_ROOT, TLMGR_ROOT, TLMGR_VERSION, CONFIG_DIR, REPOS_CONF

# Get all git repositories (excluding the umbrella repo itself)
get_tools() {
    local tools=()

    # Find all .git directories up to 3 levels deep, excluding the root
    while IFS= read -r -d '' git_dir; do
        local repo_path=$(dirname "$git_dir")
        # Skip the umbrella repo itself
        if [[ "$repo_path" != "$TOOLS_ROOT" ]]; then
            tools+=("$repo_path")
        fi
    done < <(find "$TOOLS_ROOT" -type d -name .git -maxdepth 3 -print0 2>/dev/null)

    # Sort and output
    printf '%s\n' "${tools[@]}" | sort
}

# Run command in each tool directory
for_each_tool() {
    local cmd="$1"
    local description="$2"
    local show_empty="${3:-false}"

    header "$description"
    echo

    local count=0
    while IFS= read -r tool_path; do
        local tool=$(rel_path "$tool_path")

        tool_name "$tool"
        local output
        if output=$(cd "$tool_path" && eval "$cmd" 2>&1); then
            if [[ -n "$output" ]] || [[ "$show_empty" == "true" ]]; then
                echo "$output"
                count=$((count+1))
            else
                echo "(no output)"
            fi
        else
            error "command failed"
            echo "$output"
        fi
        echo
    done < <(get_tools)

    if [[ $count -eq 0 ]] && [[ "$show_empty" == "false" ]]; then
        info "No results"
        echo
    fi
}

# --- Subcommands ---

# Show status of all tools
cmd_status() {
    for_each_tool "git status -sb" "Repository Status" true
}

# Pull all tools
cmd_pull() {
    for_each_tool "git pull --rebase" "Pulling Updates" true
}

# Fetch all tools
cmd_fetch() {
    for_each_tool "git fetch --all --prune" "Fetching All Remotes" true
}

# Show current branch for all tools
cmd_branches() {
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        local repos=()
        while IFS= read -r tool_path; do
            local tool=$(rel_path "$tool_path")
            local branch=$(git_safe -C "$tool_path" branch --show-current)
            [[ -z "$branch" ]] && branch="detached"

            local remote=$(git_safe -C "$tool_path" rev-parse --abbrev-ref @{u})
            [[ -z "$remote" ]] && remote="null"

            local json="{\"path\":\"$(json_escape "$tool")\",\"branch\":\"$(json_escape "$branch")\",\"upstream\":$(if [[ "$remote" == "null" ]]; then echo "null"; else echo "\"$(json_escape "$remote")\""; fi)}"
            repos+=("$json")
        done < <(get_tools)

        printf "[%s]" "$(IFS=,; echo "${repos[*]}")" | jq .
    else
        header "Current Branches"
        echo

        while IFS= read -r tool_path; do
            local tool=$(rel_path "$tool_path")
            local branch=$(git_safe -C "$tool_path" branch --show-current)
            [[ -z "$branch" ]] && branch="detached"

            local remote=$(git_safe -C "$tool_path" rev-parse --abbrev-ref @{u})
            [[ -z "$remote" ]] && remote="no upstream"

            printf "%-30s ${BLUE}%-20s${NC} ${CYAN}%s${NC}\n" "$tool" "$branch" "$remote"
        done < <(get_tools)
        echo
    fi
}

# Show uncommitted changes
cmd_changes() {
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        local repos=()
        while IFS= read -r tool_path; do
            local tool=$(rel_path "$tool_path")

            if ! git -C "$tool_path" diff --quiet HEAD -- 2>/dev/null; then
                local files=$(git_safe -C "$tool_path" status -s)
                local json="{\"path\":\"$(json_escape "$tool")\",\"changes\":\"$(json_escape "$files")\"}"
                repos+=("$json")
            fi
        done < <(get_tools)

        printf "[%s]" "$(IFS=,; echo "${repos[*]}")" | jq .
    else
        header "Uncommitted Changes"
        echo

        local found=false
        while IFS= read -r tool_path; do
            local tool=$(rel_path "$tool_path")

            if ! git -C "$tool_path" diff --quiet HEAD -- 2>/dev/null; then
                tool_name "$tool"
                git_safe -C "$tool_path" status -s
                echo
                found=true
            fi
        done < <(get_tools)

        if [[ "$found" == "false" ]]; then
            info "No uncommitted changes"
            echo
        fi
    fi
}

# Show unpushed commits
cmd_unpushed() {
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        local repos=()
        while IFS= read -r tool_path; do
            local tool=$(rel_path "$tool_path")

            local unpushed=$(git_safe -C "$tool_path" log @{u}.. --oneline | wc -l | tr -d ' ')
            [[ -z "$unpushed" ]] && unpushed=0

            if [[ $unpushed -gt 0 ]]; then
                local commits=$(git_safe -C "$tool_path" log @{u}.. --oneline)
                local json="{\"path\":\"$(json_escape "$tool")\",\"unpushed_count\":$unpushed,\"commits\":\"$(json_escape "$commits")\"}"
                repos+=("$json")
            fi
        done < <(get_tools)

        printf "[%s]" "$(IFS=,; echo "${repos[*]}")" | jq .
    else
        header "Unpushed Commits"
        echo

        local found=false
        while IFS= read -r tool_path; do
            local tool=$(rel_path "$tool_path")

            local unpushed=$(git_safe -C "$tool_path" log @{u}.. --oneline | wc -l | tr -d ' ')
            [[ -z "$unpushed" ]] && unpushed=0

            if [[ $unpushed -gt 0 ]]; then
                printf "${GREEN}▶ %s${NC} ${CYAN}(%s commits)${NC}\n" "$tool" "$unpushed"
                git_safe -C "$tool_path" log @{u}.. --oneline --color=always
                echo
                found=true
            fi
        done < <(get_tools)

        if [[ "$found" == "false" ]]; then
            info "No unpushed commits"
            echo
        fi
    fi
}

# Show untracked files
cmd_untracked() {
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        local repos=()
        while IFS= read -r tool_path; do
            local tool=$(rel_path "$tool_path")

            local untracked=$(git_safe -C "$tool_path" ls-files --others --exclude-standard)
            if [[ -n "$untracked" ]]; then
                local json="{\"path\":\"$(json_escape "$tool")\",\"untracked_files\":\"$(json_escape "$untracked")\"}"
                repos+=("$json")
            fi
        done < <(get_tools)

        printf "[%s]" "$(IFS=,; echo "${repos[*]}")" | jq .
    else
        header "Untracked Files"
        echo

        local found=false
        while IFS= read -r tool_path; do
            local tool=$(rel_path "$tool_path")

            local untracked=$(git_safe -C "$tool_path" ls-files --others --exclude-standard)
            if [[ -n "$untracked" ]]; then
                tool_name "$tool"
                echo "$untracked"
                echo
                found=true
            fi
        done < <(get_tools)

        if [[ "$found" == "false" ]]; then
            info "No untracked files"
            echo
        fi
    fi
}

# Clone a new tool
cmd_clone() {
    local url="$1"
    local name="${2:-}"

    if [[ -z "$url" ]]; then
        error "Usage: tlmgr clone <git-url> [name]"
        exit 1
    fi

    if [[ -z "$name" ]]; then
        name=$(basename "$url" .git)
    fi

    header "Cloning $name"
    git clone "$url" "$TOOLS_ROOT/$name"

    echo
    info "Successfully cloned $name"
}

# Run custom command in all tools
cmd_exec() {
    if [[ $# -eq 0 ]]; then
        error "Usage: tlmgr exec <command>"
        exit 1
    fi

    for_each_tool "$*" "Running: $*" true
}

# List all tools
cmd_list() {
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        local repos=()
        while IFS= read -r tool_path; do
            local tool=$(rel_path "$tool_path")
            local branch=$(git_safe -C "$tool_path" branch --show-current)
            [[ -z "$branch" ]] && branch="detached"

            local has_changes=false
            if ! git -C "$tool_path" diff --quiet HEAD -- 2>/dev/null; then
                has_changes=true
            fi

            local unpushed=$(git_safe -C "$tool_path" log @{u}.. --oneline | wc -l | tr -d ' ')
            [[ -z "$unpushed" ]] && unpushed=0

            local has_untracked=false
            if [[ -n $(git_safe -C "$tool_path" ls-files --others --exclude-standard) ]]; then
                has_untracked=true
            fi

            local upstream=$(git_safe -C "$tool_path" rev-parse --abbrev-ref @{u})
            [[ -z "$upstream" ]] && upstream="null"

            local json="{\"path\":\"$(json_escape "$tool")\",\"branch\":\"$(json_escape "$branch")\",\"upstream\":$(if [[ "$upstream" == "null" ]]; then echo "null"; else echo "\"$(json_escape "$upstream")\""; fi),\"has_changes\":$has_changes,\"unpushed_commits\":$unpushed,\"has_untracked\":$has_untracked,\"is_clean\":$(if [[ "$has_changes" == "false" && "$unpushed" == "0" && "$has_untracked" == "false" ]]; then echo "true"; else echo "false"; fi)}"

            repos+=("$json")
        done < <(get_tools)

        printf "[%s]" "$(IFS=,; echo "${repos[*]}")" | jq .
    else
        header "Tools"
        echo

        local total=0
        while IFS= read -r tool_path; do
            local tool=$(rel_path "$tool_path")
            local branch=$(git_safe -C "$tool_path" branch --show-current)
            [[ -z "$branch" ]] && branch="detached"

            local status=""

            # Check for changes
            if ! git -C "$tool_path" diff --quiet HEAD -- 2>/dev/null; then
                status="${status}${YELLOW}M${NC} "
            fi

            # Check for unpushed commits
            local unpushed=$(git_safe -C "$tool_path" log @{u}.. --oneline | wc -l | tr -d ' ')
            [[ -z "$unpushed" ]] && unpushed=0
            if [[ $unpushed -gt 0 ]]; then
                status="${status}${CYAN}↑${unpushed}${NC} "
            fi

            # Check for untracked files
            if [[ -n $(git_safe -C "$tool_path" ls-files --others --exclude-standard) ]]; then
                status="${status}${RED}?${NC} "
            fi

            [[ -z "$status" ]] && status="${GREEN}✓${NC}"

            printf "  %-30s ${BLUE}%-20s${NC} %b\n" "$tool" "$branch" "$status"
            total=$((total + 1))
        done < <(get_tools)

        echo
        info "Total: $total repositories"
        echo
        printf "Legend: %b=clean  %b=modified  %b=unpushed  %b=untracked\n" \
            "${GREEN}✓${NC}" "${YELLOW}M${NC}" "${CYAN}↑${NC}" "${RED}?${NC}"
        echo
    fi
}

# Show summary
cmd_summary() {
    local total=0
    local clean=0
    local modified=0
    local unpushed=0
    local untracked=0

    while IFS= read -r tool_path; do
        total=$((total + 1))

        local is_clean=true

        if ! git -C "$tool_path" diff --quiet HEAD -- 2>/dev/null; then
            modified=$((modified + 1))
            is_clean=false
        fi

        local unpushed_count=$(git_safe -C "$tool_path" log @{u}.. --oneline | wc -l | tr -d ' ')
        [[ -z "$unpushed_count" ]] && unpushed_count=0
        if [[ $unpushed_count -gt 0 ]]; then
            unpushed=$((unpushed + 1))
            is_clean=false
        fi

        if [[ -n $(git_safe -C "$tool_path" ls-files --others --exclude-standard) ]]; then
            untracked=$((untracked + 1))
            is_clean=false
        fi

        if [[ "$is_clean" == "true" ]]; then
            clean=$((clean + 1))
        fi
    done < <(get_tools)

    if [[ "$JSON_OUTPUT" == "true" ]]; then
        local needs_attention=$((total - clean))
        printf '{"total":%d,"clean":%d,"needs_attention":%d,"modified":%d,"unpushed":%d,"untracked":%d}' \
            "$total" "$clean" "$needs_attention" "$modified" "$unpushed" "$untracked" | jq .
    else
        header "Tools Summary"
        echo

        printf "Total repositories: %s\n" "$total"
        printf "%bClean:%b %s\n" "${GREEN}" "${NC}" "$clean"
        printf "%bModified:%b %s\n" "${YELLOW}" "${NC}" "$modified"
        printf "%bUnpushed:%b %s\n" "${CYAN}" "${NC}" "$unpushed"
        printf "%bUntracked:%b %s\n" "${RED}" "${NC}" "$untracked"
        echo
    fi
}

# Bootstrap repos from config
cmd_bootstrap() {
    if [[ ! -f "$REPOS_CONF" ]]; then
        error "Config not found: $REPOS_CONF"
        info "Run 'tlmgr config' to check configuration paths"
        exit 1
    fi

    header "Bootstrapping from $REPOS_CONF"
    echo

    local cloned=0
    local skipped=0
    local failed=0

    while IFS= read -r line; do
        # Strip comments and blank lines
        line="${line%%#*}"
        [[ -z "${line// }" ]] && continue

        # Parse name and url
        read -r name url <<< "$line"
        if [[ -z "$name" || -z "$url" ]]; then
            warning "Skipping malformed line: $line"
            continue
        fi

        dest="$TOOLS_ROOT/$name"
        if [[ -d "$dest" ]]; then
            echo "  skip  $name (already exists)"
            ((skipped++)) || true
        else
            echo "  clone $name ..."
            if git clone "$url" "$dest"; then
                ((cloned++)) || true
            else
                echo "  FAIL  $name" >&2
                ((failed++)) || true
            fi
        fi
    done < "$REPOS_CONF"

    echo
    info "Done: $cloned cloned, $skipped skipped, $failed failed"

    if ((failed > 0)); then
        exit 1
    fi
}

# Show version
cmd_version() {
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        printf '{"version":"%s","tools_root":"%s","config_dir":"%s"}' \
            "$TLMGR_VERSION" \
            "$(json_escape "$TOOLS_ROOT")" \
            "$(json_escape "$CONFIG_DIR")" | jq .
    else
        echo "tlmgr $TLMGR_VERSION"
    fi
}

# Show config paths
cmd_config() {
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        printf '{"tools_root":"%s","tlmgr_root":"%s","config_dir":"%s","repos_conf":"%s","version":"%s"}' \
            "$(json_escape "$TOOLS_ROOT")" \
            "$(json_escape "$TLMGR_ROOT")" \
            "$(json_escape "$CONFIG_DIR")" \
            "$(json_escape "$REPOS_CONF")" \
            "$TLMGR_VERSION" | jq .
    else
        header "Configuration"
        echo
        printf "%-15s %s\n" "tools_root:" "$TOOLS_ROOT"
        printf "%-15s %s\n" "tlmgr_root:" "$TLMGR_ROOT"
        printf "%-15s %s\n" "config_dir:" "$CONFIG_DIR"
        printf "%-15s %s\n" "repos_conf:" "$REPOS_CONF"
        printf "%-15s %s\n" "version:" "$TLMGR_VERSION"
        echo
    fi
}

# Manage bash completion
cmd_completion() {
    local shell="${1:-}"
    local action="${2:-}"

    if [[ -z "$shell" ]]; then
        error "Usage: tlmgr completion bash [--install|--path]"
        exit 1
    fi

    if [[ "$shell" != "bash" ]]; then
        error "Unsupported shell: $shell (only 'bash' is supported)"
        exit 1
    fi

    local completion_src="$TLMGR_ROOT/data/completion.bash"

    if [[ ! -f "$completion_src" ]]; then
        error "Completion file not found: $completion_src"
        exit 1
    fi

    case "$action" in
        --install)
            local dest_dir="$HOME/.local/share/bash-completion/completions"
            mkdir -p "$dest_dir"
            cp "$completion_src" "$dest_dir/tlmgr"
            info "Installed: $dest_dir/tlmgr"
            ;;
        --path)
            echo "$completion_src"
            ;;
        "")
            cat "$completion_src"
            ;;
        *)
            error "Unknown option: $action"
            error "Usage: tlmgr completion bash [--install|--path]"
            exit 1
            ;;
    esac
}

# Resolve version for a tool directory
# Usage: _resolve_version <tool_path> <ver_var> <source_var>
# Sets nameref variables for version string and source description
_resolve_version() {
    local tool_path="$1"
    local -n _ver="$2"
    local -n _src="$3"
    local pyproject="$tool_path/pyproject.toml"

    # Try pyproject.toml first
    if [[ -f "$pyproject" ]]; then
        # Check for static version in [project]
        local static_ver
        if static_ver=$(toml_get_value "$pyproject" "project" "version"); then
            _ver="$static_ver"
            _src="pyproject.toml"
            return 0
        fi

        # Check for dynamic version via hatch
        if toml_array_contains "$pyproject" "project" "dynamic" "version"; then
            local ver_path
            if ver_path=$(toml_get_value "$pyproject" "tool.hatch.version" "path"); then
                local full_path="$tool_path/$ver_path"
                if [[ -f "$full_path" ]]; then
                    local ver_line
                    while IFS= read -r ver_line; do
                        if [[ "$ver_line" =~ __version__[[:space:]]*=[[:space:]]*\"([^\"]+)\" ]]; then
                            _ver="${BASH_REMATCH[1]}"
                            _src="$ver_path"
                            return 0
                        fi
                    done < "$full_path"
                fi
            fi
        fi
    fi

    # Fallback to VERSION file
    if [[ -f "$tool_path/VERSION" ]]; then
        _ver=$(< "$tool_path/VERSION")
        _ver="${_ver%$'\n'}"
        _src="VERSION"
        return 0
    fi

    _ver=""
    _src="unknown"
    return 1
}

# Show version for all tools
cmd_versions() {
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        local repos=()
        while IFS= read -r tool_path; do
            local tool=$(rel_path "$tool_path")
            local ver="" src=""
            _resolve_version "$tool_path" ver src || true

            local ver_json
            if [[ -n "$ver" ]]; then
                ver_json="\"$(json_escape "$ver")\""
            else
                ver_json="null"
            fi

            local json="{\"name\":\"$(json_escape "$tool")\",\"version\":$ver_json,\"source\":\"$(json_escape "$src")\"}"
            repos+=("$json")
        done < <(get_tools)

        printf "[%s]" "$(IFS=,; echo "${repos[*]}")" | jq .
    else
        header "Tool Versions"
        echo

        while IFS= read -r tool_path; do
            local tool=$(rel_path "$tool_path")
            local ver="" src=""
            _resolve_version "$tool_path" ver src || true

            if [[ -n "$ver" ]]; then
                printf "  %-30s ${GREEN}%-12s${NC} ${CYAN}(%s)${NC}\n" "$tool" "$ver" "$src"
            else
                printf "  %-30s ${YELLOW}%-12s${NC}\n" "$tool" "unknown"
            fi
        done < <(get_tools)
        echo
    fi
}

# Show CLI commands/entrypoints for all tools
cmd_commands() {
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        local repos=()
        while IFS= read -r tool_path; do
            local tool=$(rel_path "$tool_path")
            local pyproject="$tool_path/pyproject.toml"
            local cmds=()

            # Try [project.scripts] from pyproject.toml
            if [[ -f "$pyproject" ]]; then
                while IFS=$'\t' read -r cmd_name entrypoint; do
                    cmds+=("{\"command\":\"$(json_escape "$cmd_name")\",\"entrypoint\":\"$(json_escape "$entrypoint")\"}")
                done < <(toml_get_section_pairs "$pyproject" "project.scripts" 2>/dev/null || true)
            fi

            # Fallback: scan bin/ for executables
            if [[ ${#cmds[@]} -eq 0 && -d "$tool_path/bin" ]]; then
                while IFS= read -r -d '' bin_file; do
                    local cmd_name=$(basename "$bin_file")
                    cmds+=("{\"command\":\"$(json_escape "$cmd_name")\",\"entrypoint\":\"bin/$cmd_name\"}")
                done < <(find "$tool_path/bin" -maxdepth 1 -type f -perm +111 -print0 2>/dev/null | sort -z)
            fi

            # Fallback: parse install.sh for symlinks to ~/.local/bin/
            if [[ ${#cmds[@]} -eq 0 && -f "$tool_path/install.sh" ]]; then
                while IFS= read -r line; do
                    if [[ "$line" =~ ln[[:space:]]+-[a-z]*[[:space:]]+(\"[^\"]+\"|[^[:space:]]+)[[:space:]]+(\"[^\"]+\"|[^[:space:]]+) ]]; then
                        local target="${BASH_REMATCH[2]}"
                        target="${target//\"/}"
                        # Match paths ending in a bin/ directory
                        if [[ "$target" =~ /bin/([^/]+)$ ]]; then
                            local cmd_name="${BASH_REMATCH[1]}"
                            local source="${BASH_REMATCH[1]}"
                            # Get the source script from the ln command
                            local src="${line##*ln }"
                            src="${src#*-[a-z]* }"
                            src="${src%% *}"
                            src="${src//\"/}"
                            src="${src##*/}"
                            cmds+=("{\"command\":\"$(json_escape "$cmd_name")\",\"entrypoint\":\"$(json_escape "$src")\"}")
                        fi
                    fi
                done < "$tool_path/install.sh"
            fi

            # Skip tools with no commands
            [[ ${#cmds[@]} -eq 0 ]] && continue

            local cmds_json
            cmds_json=$(IFS=,; echo "${cmds[*]}")
            repos+=("{\"name\":\"$(json_escape "$tool")\",\"commands\":[$cmds_json]}")
        done < <(get_tools)

        printf "[%s]" "$(IFS=,; echo "${repos[*]}")" | jq .
    else
        header "CLI Commands"
        echo

        local found=false
        while IFS= read -r tool_path; do
            local tool=$(rel_path "$tool_path")
            local pyproject="$tool_path/pyproject.toml"
            local has_cmds=false

            # Try [project.scripts] from pyproject.toml
            if [[ -f "$pyproject" ]]; then
                local pairs=""
                if pairs=$(toml_get_section_pairs "$pyproject" "project.scripts" 2>/dev/null); then
                    tool_name "$tool"
                    while IFS=$'\t' read -r cmd_name entrypoint; do
                        printf "    %-20s %s\n" "$cmd_name" "$entrypoint"
                    done <<< "$pairs"
                    echo
                    has_cmds=true
                    found=true
                fi
            fi

            # Fallback: scan bin/ for executables
            if [[ "$has_cmds" == "false" && -d "$tool_path/bin" ]]; then
                local bin_files=()
                while IFS= read -r -d '' bin_file; do
                    bin_files+=("$bin_file")
                done < <(find "$tool_path/bin" -maxdepth 1 -type f -perm +111 -print0 2>/dev/null | sort -z)

                if [[ ${#bin_files[@]} -gt 0 ]]; then
                    tool_name "$tool"
                    for bin_file in "${bin_files[@]}"; do
                        local cmd_name=$(basename "$bin_file")
                        printf "    %-20s bin/%s\n" "$cmd_name" "$cmd_name"
                    done
                    echo
                    has_cmds=true
                    found=true
                fi
            fi

            # Fallback: parse install.sh for symlinks to ~/.local/bin/
            if [[ "$has_cmds" == "false" && -f "$tool_path/install.sh" ]]; then
                local install_cmds=()
                while IFS= read -r line; do
                    if [[ "$line" =~ ln[[:space:]]+-[a-z]*[[:space:]]+(\"[^\"]+\"|[^[:space:]]+)[[:space:]]+(\"[^\"]+\"|[^[:space:]]+) ]]; then
                        local target="${BASH_REMATCH[2]}"
                        target="${target//\"/}"
                        if [[ "$target" =~ /bin/([^/]+)$ ]]; then
                            local cmd_name="${BASH_REMATCH[1]}"
                            local src="${line##*ln }"
                            src="${src#*-[a-z]* }"
                            src="${src%% *}"
                            src="${src//\"/}"
                            src="${src##*/}"
                            install_cmds+=("$cmd_name"$'\t'"$src")
                        fi
                    fi
                done < "$tool_path/install.sh"

                if [[ ${#install_cmds[@]} -gt 0 ]]; then
                    tool_name "$tool"
                    for entry in "${install_cmds[@]}"; do
                        local cmd_name="${entry%%$'\t'*}"
                        local entrypoint="${entry#*$'\t'}"
                        printf "    %-20s %s\n" "$cmd_name" "$entrypoint"
                    done
                    echo
                    found=true
                fi
            fi
        done < <(get_tools)

        if [[ "$found" == "false" ]]; then
            info "No CLI commands found"
            echo
        fi
    fi
}

# Show help
cmd_help() {
    cat << 'EOF'
Usage: tlmgr [--json] <command> [args]

Inventory:
  list (ls)         List all tools with status [default]
  summary           Show aggregate statistics
  versions (ver)    Show version for each tool
  commands (cmds)   Show CLI entrypoints for each tool

Git state:
  branches (br)     Show current branch for all tools
  changes (ch)      Show uncommitted changes
  unpushed (up)     Show unpushed commits
  untracked (ut)    Show untracked files
  status (st)       Show full git status

Operations:
  pull              Pull (rebase) all tools
  fetch             Fetch all remotes
  clone <url>       Clone a new tool repository
  exec <cmd>        Run command in all tool directories
  bootstrap (boot)  Clone repos from config

Config:
  config (cfg)      Show configuration paths
  version           Show tlmgr version
  completion bash   Manage bash completion
  help              Show this help

Options:
  --json            JSON output (inventory + git-state commands)
  --version         Show version

Examples:
  tlmgr                              List all tools
  tlmgr changes                      What needs committing?
  tlmgr --json list | jq '.[] | select(.has_changes)'
EOF
}
