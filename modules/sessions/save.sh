#!/usr/bin/env bash
# pimpmytmux - Session save functionality
# Saves tmux session state for later restoration

# Guard against re-sourcing
[[ -n "${_PIMPMYTMUX_SESSION_SAVE_LOADED:-}" ]] && return 0
_PIMPMYTMUX_SESSION_SAVE_LOADED=1

# shellcheck source=lib/core.sh
source "${PIMPMYTMUX_LIB_DIR:-$(dirname "${BASH_SOURCE[0]}")/../../lib}/core.sh"

# -----------------------------------------------------------------------------
# Session save directory
# -----------------------------------------------------------------------------

PIMPMYTMUX_SESSIONS_DIR="${PIMPMYTMUX_DATA_DIR}/sessions"

# -----------------------------------------------------------------------------
# Session capture functions
# -----------------------------------------------------------------------------

## Get current pane's working directory
_get_pane_cwd() {
    local pane_id="$1"
    tmux display-message -p -t "$pane_id" '#{pane_current_path}' 2>/dev/null
}

## Get current pane's command
_get_pane_command() {
    local pane_id="$1"
    tmux display-message -p -t "$pane_id" '#{pane_current_command}' 2>/dev/null
}

## Capture a single pane's state
_capture_pane() {
    local session="$1"
    local window_index="$2"
    local pane_index="$3"
    local pane_id="${session}:${window_index}.${pane_index}"

    local cwd command active width height

    cwd=$(_get_pane_cwd "$pane_id")
    command=$(_get_pane_command "$pane_id")
    active=$(tmux display-message -p -t "$pane_id" '#{pane_active}' 2>/dev/null)
    width=$(tmux display-message -p -t "$pane_id" '#{pane_width}' 2>/dev/null)
    height=$(tmux display-message -p -t "$pane_id" '#{pane_height}' 2>/dev/null)

    cat << EOF
      {
        "index": ${pane_index},
        "cwd": "${cwd}",
        "command": "${command}",
        "active": ${active:-0},
        "width": ${width:-80},
        "height": ${height:-24}
      }
EOF
}

## Capture a single window's state
_capture_window() {
    local session="$1"
    local window_index="$2"

    local window_name window_active pane_count layout
    local window_id="${session}:${window_index}"

    window_name=$(tmux display-message -p -t "$window_id" '#{window_name}' 2>/dev/null)
    window_active=$(tmux display-message -p -t "$window_id" '#{window_active}' 2>/dev/null)
    pane_count=$(tmux display-message -p -t "$window_id" '#{window_panes}' 2>/dev/null)
    layout=$(tmux display-message -p -t "$window_id" '#{window_layout}' 2>/dev/null)

    cat << EOF
    {
      "index": ${window_index},
      "name": "${window_name}",
      "active": ${window_active:-0},
      "layout": "${layout}",
      "panes": [
EOF

    local first_pane=true
    for pane_index in $(tmux list-panes -t "$window_id" -F '#{pane_index}'); do
        if [[ "$first_pane" == "true" ]]; then
            first_pane=false
        else
            echo ","
        fi
        _capture_pane "$session" "$window_index" "$pane_index"
    done

    cat << EOF

      ]
    }
EOF
}

## Capture entire session state
capture_session() {
    local session_name="${1:-$(tmux display-message -p '#S')}"

    if ! tmux has-session -t "$session_name" 2>/dev/null; then
        log_error "Session not found: $session_name"
        return 1
    fi

    local window_count
    window_count=$(tmux display-message -p -t "$session_name" '#{session_windows}')

    cat << EOF
{
  "version": "1.0",
  "timestamp": "$(date -Iseconds)",
  "session": {
    "name": "${session_name}",
    "windows": [
EOF

    local first_window=true
    for window_index in $(tmux list-windows -t "$session_name" -F '#{window_index}'); do
        if [[ "$first_window" == "true" ]]; then
            first_window=false
        else
            echo ","
        fi
        _capture_window "$session_name" "$window_index"
    done

    cat << EOF

    ]
  }
}
EOF
}

## Save session to file
save_session() {
    local session_name="${1:-$(tmux display-message -p '#S')}"
    local save_name="${2:-$session_name}"

    ensure_dir "$PIMPMYTMUX_SESSIONS_DIR"

    local save_file="${PIMPMYTMUX_SESSIONS_DIR}/${save_name}.json"

    log_info "Saving session: $session_name"

    if capture_session "$session_name" > "$save_file"; then
        log_success "Session saved: $save_file"
        return 0
    else
        log_error "Failed to save session"
        rm -f "$save_file"
        return 1
    fi
}

## Save all sessions
save_all_sessions() {
    local sessions
    sessions=$(tmux list-sessions -F '#{session_name}' 2>/dev/null)

    if [[ -z "$sessions" ]]; then
        log_warn "No sessions to save"
        return 0
    fi

    ensure_dir "$PIMPMYTMUX_SESSIONS_DIR"

    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)

    for session in $sessions; do
        save_session "$session" "${session}_${timestamp}"
    done

    # Also save a "last" snapshot
    local last_file="${PIMPMYTMUX_SESSIONS_DIR}/_last.json"
    echo "{" > "$last_file"
    echo '  "timestamp": "'$(date -Iseconds)'",' >> "$last_file"
    echo '  "sessions": [' >> "$last_file"

    local first=true
    for session in $sessions; do
        if [[ "$first" == "true" ]]; then
            first=false
        else
            echo "," >> "$last_file"
        fi
        echo "    \"${session}\"" >> "$last_file"
    done

    echo '  ]' >> "$last_file"
    echo '}' >> "$last_file"

    log_success "Saved all sessions"
}

## List saved sessions
list_saved_sessions() {
    if [[ ! -d "$PIMPMYTMUX_SESSIONS_DIR" ]]; then
        log_info "No saved sessions"
        return 0
    fi

    echo "Saved sessions:"
    for file in "$PIMPMYTMUX_SESSIONS_DIR"/*.json; do
        if [[ -f "$file" ]]; then
            local name
            name=$(basename "$file" .json)
            [[ "$name" == "_last" ]] && continue

            local timestamp
            if check_command jq; then
                timestamp=$(jq -r '.timestamp // "unknown"' "$file" 2>/dev/null)
            else
                timestamp=$(grep -o '"timestamp":[^,]*' "$file" | head -1 | cut -d'"' -f4)
            fi

            echo "  - $name ($timestamp)"
        fi
    done
}

## Auto-save hook (called before tmux exits)
auto_save_hook() {
    if config_enabled ".modules.sessions.auto_save"; then
        save_all_sessions
    fi
}
