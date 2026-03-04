# lib/toml.sh — Lightweight TOML extraction helpers for tlmgr
# Sourced by bin/tlmgr
# Pure bash: read loop + regex, no external dependencies
# Section-aware: tracks [section] headers, exits when leaving target section

# Get a quoted string value from a TOML section
# Usage: toml_get_value <file> <section> <key>
# Example: toml_get_value pyproject.toml "project" "version"
# Outputs the unquoted value, or returns 1 if not found
toml_get_value() {
    local file="$1" section="$2" key="$3"
    local in_section=false

    while IFS= read -r line; do
        # Strip leading/trailing whitespace
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"

        # Track section headers
        if [[ "$line" =~ ^\[([^]]+)\]$ ]]; then
            local current="${BASH_REMATCH[1]}"
            if [[ "$current" == "$section" ]]; then
                in_section=true
            elif [[ "$in_section" == "true" ]]; then
                return 1  # Left target section without finding key
            fi
            continue
        fi

        if [[ "$in_section" == "true" ]]; then
            # Match key = "value" or key = 'value'
            if [[ "$line" =~ ^${key}[[:space:]]*=[[:space:]]*\"([^\"]*)\" ]]; then
                echo "${BASH_REMATCH[1]}"
                return 0
            elif [[ "$line" =~ ^${key}[[:space:]]*=[[:space:]]*\'([^\']*)\' ]]; then
                echo "${BASH_REMATCH[1]}"
                return 0
            fi
        fi
    done < "$file"
    return 1
}

# Check if a value appears in a TOML array within a section
# Usage: toml_array_contains <file> <section> <key> <needle>
# Example: toml_array_contains pyproject.toml "project" "dynamic" "version"
# Returns 0 if found, 1 if not
toml_array_contains() {
    local file="$1" section="$2" key="$3" needle="$4"
    local in_section=false

    while IFS= read -r line; do
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"

        if [[ "$line" =~ ^\[([^]]+)\]$ ]]; then
            local current="${BASH_REMATCH[1]}"
            if [[ "$current" == "$section" ]]; then
                in_section=true
            elif [[ "$in_section" == "true" ]]; then
                return 1
            fi
            continue
        fi

        if [[ "$in_section" == "true" ]]; then
            if [[ "$line" =~ ^${key}[[:space:]]*= ]]; then
                if [[ "$line" == *"\"$needle\""* ]] || [[ "$line" == *"'$needle'"* ]]; then
                    return 0
                fi
                return 1
            fi
        fi
    done < "$file"
    return 1
}

# Extract all key = "value" pairs from a TOML section
# Usage: toml_get_section_pairs <file> <section>
# Outputs lines of: key<TAB>value
# Returns 1 if section not found or empty
toml_get_section_pairs() {
    local file="$1" section="$2"
    local in_section=false
    local found=false

    while IFS= read -r line; do
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"

        if [[ "$line" =~ ^\[([^]]+)\]$ ]]; then
            local current="${BASH_REMATCH[1]}"
            if [[ "$current" == "$section" ]]; then
                in_section=true
            elif [[ "$in_section" == "true" ]]; then
                break
            fi
            continue
        fi

        if [[ "$in_section" == "true" ]]; then
            if [[ "$line" =~ ^([a-zA-Z0-9_-]+)[[:space:]]*=[[:space:]]*\"([^\"]*)\" ]]; then
                printf '%s\t%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
                found=true
            fi
        fi
    done < "$file"

    [[ "$found" == "true" ]] && return 0 || return 1
}
