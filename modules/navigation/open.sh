#!/usr/bin/env bash
# pimpmytmux - tmux-open integration
# Open files, URLs and search selections from copy mode

# Guard against re-sourcing
[[ -n "${_PIMPMYTMUX_OPEN_LOADED:-}" ]] && return 0
_PIMPMYTMUX_OPEN_LOADED=1

# -----------------------------------------------------------------------------
# Open helpers
# -----------------------------------------------------------------------------

## Get the platform open command (xdg-open, open, or custom)
## Returns: command string
get_open_command() {
    local custom_cmd
    custom_cmd=$(get_config ".modules.navigation.open.open_command" "")

    if [[ -n "$custom_cmd" ]]; then
        echo "$custom_cmd"
        return 0
    fi

    local platform
    platform=$(get_platform)

    case "$platform" in
        macos)
            echo "open"
            ;;
        *)
            echo "xdg-open"
            ;;
    esac
}

## Get the editor command
## Priority: config > $EDITOR > nvim > vim > vi
get_editor_command() {
    local custom_editor
    custom_editor=$(get_config ".modules.navigation.open.editor" "")

    if [[ -n "$custom_editor" ]]; then
        echo "$custom_editor"
        return 0
    fi

    if [[ -n "${EDITOR:-}" ]]; then
        echo "$EDITOR"
        return 0
    fi

    # Fallback chain
    for editor in nvim vim vi; do
        if command -v "$editor" &>/dev/null; then
            echo "$editor"
            return 0
        fi
    done

    echo "vi"
}

# -----------------------------------------------------------------------------
# Open configuration generator
# -----------------------------------------------------------------------------

## Generate open bindings for copy-mode-vi
## Usage: generate_open_bindings <open_cmd> <editor_cmd> <search_engine>
generate_open_bindings() {
    local open_cmd="$1"
    local editor_cmd="$2"
    local search_engine="$3"

    cat << EOF
# -----------------------------------------------------------------------------
# Open Bindings (tmux-open style)
# -----------------------------------------------------------------------------

# Open selection with system opener (o in copy mode)
bind -T copy-mode-vi o send-keys -X copy-pipe-and-cancel "${open_cmd}"

# Open selection with editor in a split (C-o in copy mode)
bind -T copy-mode-vi C-o send-keys -X copy-pipe-and-cancel "xargs -I {} tmux split-window -h '${editor_cmd} {}'"

# Search selection in browser (S in copy mode)
bind -T copy-mode-vi S send-keys -X copy-pipe-and-cancel "xargs -I {} ${open_cmd} '${search_engine}{}'"

EOF
}

## Main entry point: generate all open configuration
generate_open_config() {
    local open_cmd editor_cmd search_engine

    open_cmd=$(get_open_command)
    editor_cmd=$(get_editor_command)
    search_engine=$(get_config ".modules.navigation.open.search_engine" "https://www.google.com/search?q=")

    generate_open_bindings "$open_cmd" "$editor_cmd" "$search_engine"
}
