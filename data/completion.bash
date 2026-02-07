# Bash completion for tlmgr
# Install: tlmgr completion bash --install
# Or: source <(tlmgr completion bash)

_tlmgr_completions() {
    local cur prev words cword
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    words=("${COMP_WORDS[@]}")
    cword="$COMP_CWORD"

    # All subcommands (canonical + aliases)
    local subcommands="list ls summary branches br changes ch unpushed up untracked ut status st pull fetch clone exec bootstrap boot completion config cfg version help"

    # JSON-capable subcommands
    local json_commands="list ls summary branches br changes ch unpushed up untracked ut version config cfg"

    # Determine if --json was given
    local has_json=false
    for ((i=1; i<cword; i++)); do
        [[ "${words[i]}" == "--json" ]] && has_json=true
    done

    # Find the subcommand position (skip flags)
    local subcmd=""
    local subcmd_pos=0
    for ((i=1; i<${#words[@]}; i++)); do
        case "${words[i]}" in
            --json|--version|--help|-h) continue ;;
            -*) continue ;;
            *)
                subcmd="${words[i]}"
                subcmd_pos=$i
                break
                ;;
        esac
    done

    # Position 1 or after --json: complete subcommands and flags
    if [[ -z "$subcmd" ]] || [[ "$cword" -eq "$subcmd_pos" ]]; then
        if [[ "$cur" == -* ]]; then
            COMPREPLY=($(compgen -W "--json --version --help" -- "$cur"))
        elif [[ "$has_json" == "true" ]]; then
            # After --json, only offer JSON-capable commands
            COMPREPLY=($(compgen -W "$json_commands" -- "$cur"))
        else
            COMPREPLY=($(compgen -W "$subcommands" -- "$cur"))
        fi
        return 0
    fi

    # Handle completion subcommand
    if [[ "$subcmd" == "completion" ]]; then
        local comp_pos=$((subcmd_pos + 1))
        if [[ "$cword" -eq "$comp_pos" ]]; then
            COMPREPLY=($(compgen -W "bash" -- "$cur"))
        elif [[ "$cur" == -* ]]; then
            COMPREPLY=($(compgen -W "--install --path" -- "$cur"))
        fi
        return 0
    fi

    # Handle clone: no special completion (user provides URL)
    if [[ "$subcmd" == "clone" ]]; then
        return 0
    fi

    # Handle exec: no completion (user provides command string)
    if [[ "$subcmd" == "exec" ]]; then
        return 0
    fi

    # Default: no further completion for other subcommands
    return 0
}

complete -F _tlmgr_completions tlmgr
