#!/usr/bin/env bash
# pimpmytmux - Session restore functionality
# Restores tmux sessions from saved state

# Guard against re-sourcing
[[ -n "${_PIMPMYTMUX_SESSION_RESTORE_LOADED:-}" ]] && return 0
_PIMPMYTMUX_SESSION_RESTORE_LOADED=1

# shellcheck source=lib/core.sh
source "${PIMPMYTMUX_LIB_DIR:-$(dirname "${BASH_SOURCE[0]}")/../../lib}/core.sh"

# -----------------------------------------------------------------------------
# Session restore directory
# -----------------------------------------------------------------------------

PIMPMYTMUX_SESSIONS_DIR="${PIMPMYTMUX_DATA_DIR}/sessions"

# -----------------------------------------------------------------------------
# JSON parsing helpers (works without jq)
# -----------------------------------------------------------------------------

## Simple JSON value extractor
_json_get() {
    local json="$1"
    local key="$2"
    echo "$json" | grep -o "\"${key}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/'
}

## Simple JSON number extractor
_json_get_num() {
    local json="$1"
    local key="$2"
    echo "$json" | grep -o "\"${key}\"[[:space:]]*:[[:space:]]*[0-9]*" | head -1 | sed 's/.*: *//'
}

# -----------------------------------------------------------------------------
# Session restore functions
# -----------------------------------------------------------------------------

## Restore a pane from saved state
_restore_pane() {
    local target_window="$1"
    local pane_data="$2"
    local is_first="$3"

    local cwd command

    if check_command jq; then
        cwd=$(echo "$pane_data" | jq -r '.cwd // ""')
        command=$(echo "$pane_data" | jq -r '.command // ""')
    else
        cwd=$(_json_get "$pane_data" "cwd")
        command=$(_json_get "$pane_data" "command")
    fi

    # Default to home if cwd doesn't exist
    [[ ! -d "$cwd" ]] && cwd="$HOME"

    if [[ "$is_first" == "true" ]]; then
        # First pane - just change directory
        tmux send-keys -t "$target_window" "cd '$cwd'" Enter
    else
        # Additional panes - split and change directory
        tmux split-window -t "$target_window" -c "$cwd"
    fi

    # Optionally restart command (only for known safe commands)
    case "$command" in
        vim|nvim|nano|emacs)
            # Don't auto-restart editors
            ;;
        bash|zsh|fish|sh)
            # Shell is already running
            ;;
        *)
            # Log the command that was running
            log_debug "Previous command was: $command"
            ;;
    esac
}

## Restore a window from saved state
_restore_window() {
    local session_name="$1"
    local window_data="$2"
    local is_first="$3"

    local window_name layout

    if check_command jq; then
        window_name=$(echo "$window_data" | jq -r '.name // "window"')
        layout=$(echo "$window_data" | jq -r '.layout // ""')
    else
        window_name=$(_json_get "$window_data" "name")
        layout=$(_json_get "$window_data" "layout")
    fi

    local target_window

    if [[ "$is_first" == "true" ]]; then
        # First window - rename existing window
        target_window="${session_name}:1"
        tmux rename-window -t "$target_window" "$window_name"
    else
        # Additional windows - create new window
        tmux new-window -t "$session_name" -n "$window_name"
        target_window="${session_name}:!"  # Last created window
    fi

    # Restore panes
    local panes first_pane=true

    if check_command jq; then
        panes=$(echo "$window_data" | jq -c '.panes[]' 2>/dev/null)
    else
        # Simplified: just restore single pane with first cwd found
        local cwd
        cwd=$(_json_get "$window_data" "cwd")
        [[ -d "$cwd" ]] && tmux send-keys -t "$target_window" "cd '$cwd'" Enter
        panes=""
    fi

    if [[ -n "$panes" ]]; then
        while IFS= read -r pane_data; do
            _restore_pane "$target_window" "$pane_data" "$first_pane"
            first_pane=false
        done <<< "$panes"
    fi

    # Apply layout if available
    if [[ -n "$layout" && "$layout" != "null" ]]; then
        tmux select-layout -t "$target_window" "$layout" 2>/dev/null || true
    fi
}

## Restore a session from file
restore_session() {
    local save_name="$1"
    local save_file="${PIMPMYTMUX_SESSIONS_DIR}/${save_name}.json"

    if [[ ! -f "$save_file" ]]; then
        log_error "Saved session not found: $save_name"
        return 1
    fi

    log_info "Restoring session: $save_name"

    local session_name windows_data

    if check_command jq; then
        session_name=$(jq -r '.session.name // "restored"' "$save_file")
        windows_data=$(jq -c '.session.windows[]' "$save_file" 2>/dev/null)
    else
        session_name=$(_json_get "$(cat "$save_file")" "name")
        [[ -z "$session_name" ]] && session_name="restored"
        windows_data=""
    fi

    # Check if session already exists
    if tmux has-session -t "$session_name" 2>/dev/null; then
        log_warn "Session '$session_name' already exists"
        read -rp "Overwrite? [y/N] " answer
        if [[ ! "$answer" =~ ^[Yy]$ ]]; then
            return 1
        fi
        tmux kill-session -t "$session_name"
    fi

    # Create new session
    tmux new-session -d -s "$session_name"

    # Restore windows
    local first_window=true
    if [[ -n "$windows_data" ]]; then
        while IFS= read -r window_data; do
            _restore_window "$session_name" "$window_data" "$first_window"
            first_window=false
        done <<< "$windows_data"
    fi

    log_success "Restored session: $session_name"

    # Switch to restored session if inside tmux
    if is_inside_tmux; then
        tmux switch-client -t "$session_name"
    else
        echo "Attach with: tmux attach -t $session_name"
    fi
}

## Restore last saved sessions
restore_last() {
    local last_file="${PIMPMYTMUX_SESSIONS_DIR}/_last.json"

    if [[ ! -f "$last_file" ]]; then
        log_warn "No last session snapshot found"
        return 1
    fi

    log_info "Restoring last session snapshot..."

    local sessions

    if check_command jq; then
        sessions=$(jq -r '.sessions[]' "$last_file" 2>/dev/null)
    else
        sessions=$(grep -o '"[^"]*"' "$last_file" | grep -v timestamp | tr -d '"')
    fi

    for session in $sessions; do
        local session_file="${PIMPMYTMUX_SESSIONS_DIR}/${session}.json"
        # Find most recent save for this session
        local latest
        latest=$(ls -t "${PIMPMYTMUX_SESSIONS_DIR}/${session}"*.json 2>/dev/null | head -1)

        if [[ -n "$latest" ]]; then
            restore_session "$(basename "$latest" .json)"
        fi
    done
}

## Auto-restore hook (called on tmux start)
auto_restore_hook() {
    if config_enabled ".modules.sessions.auto_restore"; then
        if [[ -f "${PIMPMYTMUX_SESSIONS_DIR}/_last.json" ]]; then
            restore_last
        fi
    fi
}

## Interactive session chooser (with fzf if available)
choose_session() {
    if [[ ! -d "$PIMPMYTMUX_SESSIONS_DIR" ]]; then
        log_warn "No saved sessions"
        return 1
    fi

    local sessions=()
    for file in "$PIMPMYTMUX_SESSIONS_DIR"/*.json; do
        [[ -f "$file" ]] || continue
        local name
        name=$(basename "$file" .json)
        [[ "$name" == "_last" ]] && continue
        sessions+=("$name")
    done

    if [[ ${#sessions[@]} -eq 0 ]]; then
        log_warn "No saved sessions found"
        return 1
    fi

    local choice

    if check_command fzf; then
        choice=$(printf '%s\n' "${sessions[@]}" | fzf --prompt="Select session to restore: ")
    else
        echo "Available sessions:"
        local i=1
        for s in "${sessions[@]}"; do
            echo "  $i) $s"
            ((i++))
        done
        read -rp "Enter number: " num
        choice="${sessions[$((num-1))]}"
    fi

    if [[ -n "$choice" ]]; then
        restore_session "$choice"
    fi
}
