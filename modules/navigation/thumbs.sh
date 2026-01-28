#!/usr/bin/env bash
# pimpmytmux - tmux-thumbs integration
# Quick copy by hints (requires tmux-thumbs to be installed)

# Guard against re-sourcing
[[ -n "${_PIMPMYTMUX_THUMBS_LOADED:-}" ]] && return 0
_PIMPMYTMUX_THUMBS_LOADED=1

# -----------------------------------------------------------------------------
# Thumbs helpers
# -----------------------------------------------------------------------------

## Check if tmux-thumbs is installed
## Returns: 0 if found, 1 if not
check_thumbs_installed() {
    local thumbs_path
    thumbs_path=$(get_thumbs_path)
    [[ -n "$thumbs_path" ]]
}

## Get path to tmux-thumbs executable
## Returns: path string or empty
get_thumbs_path() {
    # Check common installation locations
    local paths=(
        "${HOME}/.tmux/plugins/tmux-thumbs/tmux-thumbs.tmux"
        "${HOME}/.cargo/bin/tmux-thumbs"
    )

    for p in "${paths[@]}"; do
        if [[ -x "$p" ]]; then
            echo "$p"
            return 0
        fi
    done

    # Check PATH
    if command -v tmux-thumbs &>/dev/null; then
        command -v tmux-thumbs
        return 0
    fi

    echo ""
    return 0
}

# -----------------------------------------------------------------------------
# Thumbs configuration generator
# -----------------------------------------------------------------------------

## Generate tmux-thumbs configuration
## Reads settings from YAML config
generate_thumbs_config() {
    local key alphabet reverse unique position

    key=$(get_config ".modules.navigation.thumbs.key" "T")
    alphabet=$(get_config ".modules.navigation.thumbs.alphabet" "qwerty")
    reverse=$(get_config ".modules.navigation.thumbs.reverse" "false")
    unique=$(get_config ".modules.navigation.thumbs.unique" "false")
    position=$(get_config ".modules.navigation.thumbs.position" "left")

    cat << EOF
# -----------------------------------------------------------------------------
# Thumbs (tmux-thumbs style quick copy)
# -----------------------------------------------------------------------------

# Activate thumbs mode with prefix + ${key}
bind ${key} thumbs-pick

# Thumbs options
set -g @thumbs-alphabet ${alphabet}
set -g @thumbs-position ${position}
EOF

    if [[ "$reverse" == "true" ]]; then
        echo "set -g @thumbs-reverse enabled"
    fi

    if [[ "$unique" == "true" ]]; then
        echo "set -g @thumbs-unique enabled"
    fi

    echo ""
}
