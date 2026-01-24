#!/usr/bin/env bash
# pimpmytmux - fzf integration
# Fuzzy finding for sessions, windows, panes, and commands

# Guard against re-sourcing
[[ -n "${_PIMPMYTMUX_FZF_LOADED:-}" ]] && return 0
_PIMPMYTMUX_FZF_LOADED=1

# shellcheck source=lib/core.sh
source "${PIMPMYTMUX_LIB_DIR:-$(dirname "${BASH_SOURCE[0]}")/../../lib}/core.sh"

# -----------------------------------------------------------------------------
# fzf configuration
# -----------------------------------------------------------------------------

# Default fzf options for tmux integration
FZF_TMUX_OPTS="${FZF_TMUX_OPTS:---tmux 80%,60% --border --info=inline}"

# -----------------------------------------------------------------------------
# fzf helper functions
# -----------------------------------------------------------------------------

## Check if fzf is available
_require_fzf() {
    if ! check_command fzf; then
        log_error "fzf is required for this feature"
        log_info "Install: https://github.com/junegunn/fzf#installation"
        return 1
    fi
}

## Run fzf with tmux popup if available
_fzf_tmux() {
    if [[ -n "${TMUX:-}" ]] && check_command fzf-tmux; then
        fzf-tmux $FZF_TMUX_OPTS "$@"
    else
        fzf "$@"
    fi
}

# -----------------------------------------------------------------------------
# Session switching with fzf
# -----------------------------------------------------------------------------

## Switch session using fzf
fzf_switch_session() {
    _require_fzf || return 1

    local sessions choice

    sessions=$(tmux list-sessions -F "#{session_name}: #{session_windows} windows (#{session_attached} attached)" 2>/dev/null)

    if [[ -z "$sessions" ]]; then
        log_warn "No sessions found"
        return 1
    fi

    choice=$(echo "$sessions" | _fzf_tmux \
        --prompt="Switch session: " \
        --header="Sessions" \
        --preview="tmux list-windows -t {1}" \
        --preview-window=right:50% \
        | cut -d: -f1)

    if [[ -n "$choice" ]]; then
        tmux switch-client -t "$choice"
    fi
}

# -----------------------------------------------------------------------------
# Window switching with fzf
# -----------------------------------------------------------------------------

## Switch window using fzf
fzf_switch_window() {
    _require_fzf || return 1

    local windows choice

    windows=$(tmux list-windows -a -F "#{session_name}:#{window_index} #{window_name} #{window_flags}" 2>/dev/null)

    if [[ -z "$windows" ]]; then
        log_warn "No windows found"
        return 1
    fi

    choice=$(echo "$windows" | _fzf_tmux \
        --prompt="Switch window: " \
        --header="Windows" \
        --preview="tmux capture-pane -ep -t {1}" \
        --preview-window=right:60% \
        | awk '{print $1}')

    if [[ -n "$choice" ]]; then
        tmux select-window -t "$choice"
    fi
}

# -----------------------------------------------------------------------------
# Pane switching with fzf
# -----------------------------------------------------------------------------

## Switch pane using fzf
fzf_switch_pane() {
    _require_fzf || return 1

    local panes choice

    panes=$(tmux list-panes -a -F "#{session_name}:#{window_index}.#{pane_index} #{pane_current_path} #{pane_current_command}" 2>/dev/null)

    if [[ -z "$panes" ]]; then
        log_warn "No panes found"
        return 1
    fi

    choice=$(echo "$panes" | _fzf_tmux \
        --prompt="Switch pane: " \
        --header="Panes" \
        --preview="tmux capture-pane -ep -t {1}" \
        --preview-window=right:60% \
        | awk '{print $1}')

    if [[ -n "$choice" ]]; then
        tmux switch-client -t "$choice"
    fi
}

# -----------------------------------------------------------------------------
# Command palette with fzf
# -----------------------------------------------------------------------------

## Show command palette
fzf_command_palette() {
    _require_fzf || return 1

    local commands=(
        "new-session:Create new session"
        "new-window:Create new window"
        "split-h:Split pane horizontally"
        "split-v:Split pane vertically"
        "kill-pane:Close current pane"
        "kill-window:Close current window"
        "kill-session:Close current session"
        "rename-window:Rename current window"
        "rename-session:Rename current session"
        "detach:Detach from tmux"
        "reload:Reload configuration"
        "list-keys:Show keybindings"
        "clock:Show clock"
        "layout-tiled:Tile panes"
        "layout-even-h:Even horizontal split"
        "layout-even-v:Even vertical split"
        "layout-main-h:Main horizontal layout"
        "layout-main-v:Main vertical layout"
        "zoom:Toggle pane zoom"
        "sync-panes:Toggle synchronized panes"
    )

    local choice
    choice=$(printf '%s\n' "${commands[@]}" | _fzf_tmux \
        --prompt="Command: " \
        --header="Command Palette" \
        --delimiter=":" \
        --with-nth=1 \
        --preview="echo {2}" \
        --preview-window=up:1 \
        | cut -d: -f1)

    case "$choice" in
        new-session)
            tmux command-prompt -p "Session name:" "new-session -s '%%'"
            ;;
        new-window)
            tmux new-window
            ;;
        split-h)
            tmux split-window -h
            ;;
        split-v)
            tmux split-window -v
            ;;
        kill-pane)
            tmux kill-pane
            ;;
        kill-window)
            tmux kill-window
            ;;
        kill-session)
            tmux kill-session
            ;;
        rename-window)
            tmux command-prompt -p "Window name:" "rename-window '%%'"
            ;;
        rename-session)
            tmux command-prompt -p "Session name:" "rename-session '%%'"
            ;;
        detach)
            tmux detach-client
            ;;
        reload)
            tmux source-file ~/.tmux.conf
            ;;
        list-keys)
            tmux list-keys | _fzf_tmux --prompt="Keybinding: "
            ;;
        clock)
            tmux clock-mode
            ;;
        layout-*)
            local layout="${choice#layout-}"
            tmux select-layout "${layout//-/ }"
            ;;
        zoom)
            tmux resize-pane -Z
            ;;
        sync-panes)
            tmux setw synchronize-panes
            ;;
    esac
}

# -----------------------------------------------------------------------------
# Main fzf menu
# -----------------------------------------------------------------------------

## Show main fzf menu
fzf_menu() {
    _require_fzf || return 1

    local options=(
        "session:Switch session"
        "window:Switch window"
        "pane:Switch pane"
        "command:Command palette"
    )

    local choice
    choice=$(printf '%s\n' "${options[@]}" | _fzf_tmux \
        --prompt="Action: " \
        --header="pimpmytmux Menu" \
        --delimiter=":" \
        --with-nth=1 \
        --preview="echo {2}" \
        --preview-window=up:1 \
        | cut -d: -f1)

    case "$choice" in
        session)
            fzf_switch_session
            ;;
        window)
            fzf_switch_window
            ;;
        pane)
            fzf_switch_pane
            ;;
        command)
            fzf_command_palette
            ;;
    esac
}

# -----------------------------------------------------------------------------
# Generate fzf bindings for tmux.conf
# -----------------------------------------------------------------------------

generate_fzf_bindings() {
    local script_path="${PIMPMYTMUX_ROOT}/modules/navigation/fzf-integration.sh"

    cat << EOF
# -----------------------------------------------------------------------------
# fzf Integration
# -----------------------------------------------------------------------------

# Main fzf menu
bind f run-shell -b "source '$script_path' && fzf_menu"

# Quick session switch
bind s run-shell -b "source '$script_path' && fzf_switch_session"

# Quick window switch
bind w run-shell -b "source '$script_path' && fzf_switch_window"

# Quick pane switch (useful when zoomed)
bind P run-shell -b "source '$script_path' && fzf_switch_pane"

# Command palette
bind : run-shell -b "source '$script_path' && fzf_command_palette"

EOF
}
