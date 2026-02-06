#!/usr/bin/env bash
# pimpmytmux - Claude Code status monitoring
# Detect if Claude Code is running in the current tmux pane

# Guard against re-sourcing
[[ -n "${_PIMPMYTMUX_CLAUDE_STATUS_LOADED:-}" ]] && return 0
_PIMPMYTMUX_CLAUDE_STATUS_LOADED=1

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

CLAUDE_STATUS_ICON="${CLAUDE_STATUS_ICON:-CC}"

# -----------------------------------------------------------------------------
# Detection functions
# -----------------------------------------------------------------------------

## Detect Claude Code process in current pane via pgrep
_claude_detect_pgrep() {
    local pane_pid="$1"
    if pgrep -P "$pane_pid" -f "claude" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

## Detect Claude Code process in current pane via ps (fallback)
_claude_detect_ps() {
    local pane_pid="$1"
    if ps -o pid=,ppid=,comm= 2>/dev/null | grep -q "$pane_pid.*claude"; then
        return 0
    fi
    return 1
}

## Get Claude Code status for current pane
## Returns "CC" if active, empty string if inactive
get_claude_status() {
    local pane_pid
    pane_pid=$(tmux display-message -p '#{pane_pid}' 2>/dev/null)

    if [[ -z "$pane_pid" ]]; then
        return 0
    fi

    # Try pgrep first, fall back to ps
    if check_command pgrep 2>/dev/null; then
        if _claude_detect_pgrep "$pane_pid"; then
            echo "$CLAUDE_STATUS_ICON"
            return 0
        fi
    else
        if _claude_detect_ps "$pane_pid"; then
            echo "$CLAUDE_STATUS_ICON"
            return 0
        fi
    fi

    return 0
}

# -----------------------------------------------------------------------------
# Formatting
# -----------------------------------------------------------------------------

## Format Claude indicator for tmux status bar
format_claude_indicator() {
    local status="${1:-}"

    if [[ -z "$status" ]]; then
        return 0
    fi

    echo "#[fg=green]${status}#[default]"
}

## Get formatted Claude status (detection + formatting combined)
get_claude_status_formatted() {
    local status
    status=$(get_claude_status)
    format_claude_indicator "$status"
}

# If called directly, output Claude status
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Source check_command from core if available
    if [[ -n "${PIMPMYTMUX_LIB_DIR:-}" ]]; then
        # shellcheck source=lib/core.sh
        source "${PIMPMYTMUX_LIB_DIR}/core.sh" 2>/dev/null || true
    fi
    # Fallback check_command if core not available
    if ! command -v check_command >/dev/null 2>&1; then
        check_command() { command -v "$1" >/dev/null 2>&1; }
    fi
    get_claude_status_formatted
fi
