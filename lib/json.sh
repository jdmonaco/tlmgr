# lib/json.sh — JSON output helpers for tlmgr
# Sourced by bin/tlmgr

# Check if jq is available for pretty JSON
HAS_JQ=false
if command -v jq >/dev/null 2>&1; then
    HAS_JQ=true
fi

# JSON output flag (set by --json flag)
JSON_OUTPUT=false

# JSON helper - escape strings for JSON
json_escape() {
    local str="$1"
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    str="${str//$'\n'/\\n}"
    str="${str//$'\t'/\\t}"
    echo "$str"
}

json_array_start() {
    [[ "$JSON_OUTPUT" == "true" ]] && echo "["
}

json_array_end() {
    [[ "$JSON_OUTPUT" == "true" ]] && echo "]"
}

json_object() {
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        if [[ "$HAS_JQ" == "true" ]]; then
            echo "$1" | jq -c .
        else
            echo "$1"
        fi
    fi
}
