#!/usr/bin/env bash
# Install tlmgr: symlink, bash completion, and config initialization
# Idempotent: safe to run multiple times.

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$SCRIPT_DIR/bin/tlmgr"
LINK_DIR="$HOME/.local/bin"
LINK="$LINK_DIR/tlmgr"

if [[ ! -f "$TARGET" ]]; then
    echo "Error: $TARGET not found" >&2
    exit 1
fi

# --- Symlink ---
mkdir -p "$LINK_DIR"
ln -sf "$TARGET" "$LINK"
echo "Installed: $LINK -> $TARGET"

# --- Bash Completion ---
COMP_SRC="$SCRIPT_DIR/data/completion.bash"
COMP_DIR="$HOME/.local/share/bash-completion/completions"
if [[ -f "$COMP_SRC" ]]; then
    mkdir -p "$COMP_DIR"
    cp "$COMP_SRC" "$COMP_DIR/tlmgr"
    echo "Completion: $COMP_DIR/tlmgr"
fi

# --- Config Initialization ---
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/tlmgr"
REPOS_CONF="$CONFIG_DIR/repos.conf"
DEFAULT_CONF="$SCRIPT_DIR/data/repos.conf.default"

if [[ ! -f "$REPOS_CONF" ]] && [[ -f "$DEFAULT_CONF" ]]; then
    mkdir -p "$CONFIG_DIR"
    cp "$DEFAULT_CONF" "$REPOS_CONF"
    echo "Config: $REPOS_CONF (initialized from default)"
elif [[ -f "$REPOS_CONF" ]]; then
    echo "Config: $REPOS_CONF (already exists)"
fi

# --- PATH check ---
if [[ ":$PATH:" != *":$LINK_DIR:"* ]]; then
    echo ""
    echo "Warning: $LINK_DIR is not in \$PATH" >&2
    echo "Add it to your shell profile: export PATH=\"$LINK_DIR:\$PATH\"" >&2
fi
