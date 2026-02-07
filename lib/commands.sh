# lib/commands.sh — All tlmgr subcommand implementations
# Sourced by bin/tlmgr
# Depends on: lib/output.sh, lib/json.sh
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

# Show help
cmd_help() {
    cat << EOF
Usage: tlmgr [--json] <command> [args]

Options:
    --json      Output in JSON format (for programmatic use)
    --version   Show version

Commands (with JSON support):
    list        List all tools with status (default)
    summary     Show summary statistics
    branches    Show current branch for all tools
    changes     Show tools with uncommitted changes
    unpushed    Show tools with unpushed commits
    untracked   Show tools with untracked files
    version     Show version and paths
    config      Show configuration paths

Commands (operations):
    status      Show git status for all tools
    pull        Pull (with rebase) all tools
    fetch       Fetch all remotes for all tools
    clone       Clone a new tool repository
    exec        Run a custom command in all tool directories
    bootstrap   Clone all repos from config
    completion  Manage bash completion
    help        Show this help message

Aliases:
    ls=list  br=branches  ch=changes  up=unpushed
    ut=untracked  st=status  boot=bootstrap  cfg=config

Examples:
    tlmgr                           # List all tools
    tlmgr --json list               # List in JSON format
    tlmgr summary                   # Show summary statistics
    tlmgr changes                   # Show what needs committing
    tlmgr unpushed                  # Show what needs pushing
    tlmgr pull                      # Update all repos
    tlmgr bootstrap                 # Clone repos from config
    tlmgr clone https://github.com/user/new-tool.git
    tlmgr exec "git log -1 --oneline"
    tlmgr completion bash --install # Install bash completion

JSON Filtering with jq:
    tlmgr --json list | jq '.[] | select(.has_changes)'
    tlmgr --json list | jq '.[] | select(.unpushed_commits > 0)'
    tlmgr --json branches | jq '.[] | select(.upstream == null)'

EOF
    printf "Legend:\n"
    printf "    %b = Clean (no changes)\n" "${GREEN}✓${NC}"
    printf "    %b = Modified (uncommitted changes)\n" "${YELLOW}M${NC}"
    printf "    %b = Unpushed (commits not pushed)\n" "${CYAN}↑${NC}"
    printf "    %b = Untracked (untracked files)\n" "${RED}?${NC}"
}
