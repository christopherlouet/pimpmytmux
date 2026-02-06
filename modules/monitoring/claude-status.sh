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

## Count Claude Code agents across all panes in the current window
_claude_count_window_agents() {
    local count=0
    local pane_pids

    pane_pids=$(tmux list-panes -F '#{pane_pid}' 2>/dev/null) || return 0

    while IFS= read -r pid; do
        [[ -z "$pid" ]] && continue
        if check_command pgrep 2>/dev/null; then
            if _claude_detect_pgrep "$pid"; then
                count=$((count + 1))
            fi
        else
            if _claude_detect_ps "$pid"; then
                count=$((count + 1))
            fi
        fi
    done <<< "$pane_pids"

    echo "$count"
}

## Get Claude Code status for the current window
## Returns "CC" if 1 agent, "CC:N" if N > 1, empty if none
get_claude_status() {
    local count
    count=$(_claude_count_window_agents)

    if [[ "$count" -eq 0 ]]; then
        return 0
    elif [[ "$count" -eq 1 ]]; then
        echo "$CLAUDE_STATUS_ICON"
    else
        echo "${CLAUDE_STATUS_ICON}:${count}"
    fi
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
