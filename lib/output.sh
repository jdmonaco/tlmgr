# lib/output.sh — Colors and output helpers for tlmgr
# Sourced by bin/tlmgr

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Print colored header
header() {
    printf "${BLUE}━━━ %s ━━━${NC}\n" "$1"
}

# Print tool name
tool_name() {
    printf "${GREEN}▶ %s${NC}\n" "$1"
}

# Print error
error() {
    printf "${RED}✗ %s${NC}\n" "$1" >&2
}

# Print warning
warning() {
    printf "${YELLOW}⚠ %s${NC}\n" "$1"
}

# Print info
info() {
    printf "${CYAN}ℹ %s${NC}\n" "$1"
}

# Safe git command wrapper - handles expected failures
git_safe() {
    git "$@" 2>/dev/null || true
}

# Get relative path from tools root
rel_path() {
    local path="$1"
    echo "${path#$TOOLS_ROOT/}"
}
