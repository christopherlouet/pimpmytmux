#!/usr/bin/env bash
# pimpmytmux - Theme management
# https://github.com/christopherlouet/pimpmytmux

# Guard against re-sourcing
[[ -n "${_PIMPMYTMUX_THEMES_LOADED:-}" ]] && return 0
_PIMPMYTMUX_THEMES_LOADED=1

# shellcheck source=lib/core.sh
source "${PIMPMYTMUX_LIB_DIR:-$(dirname "${BASH_SOURCE[0]}")}/core.sh"

# -----------------------------------------------------------------------------
# Theme directory
# -----------------------------------------------------------------------------

PIMPMYTMUX_THEMES_DIR="${PIMPMYTMUX_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/themes"

# -----------------------------------------------------------------------------
# Theme functions
# -----------------------------------------------------------------------------

## List all available themes
## Usage: list_themes
list_themes() {
    local themes_dir="${PIMPMYTMUX_THEMES_DIR}"

    if [[ ! -d "$themes_dir" ]]; then
        log_error "Themes directory not found: $themes_dir"
        return 1
    fi

    for theme_file in "$themes_dir"/*.yaml; do
        if [[ -f "$theme_file" ]]; then
            basename "$theme_file" .yaml
        fi
    done
}

## Get theme file path
## Usage: get_theme_path <theme_name>
get_theme_path() {
    local theme_name="$1"
    local theme_file="${PIMPMYTMUX_THEMES_DIR}/${theme_name}.yaml"

    if [[ -f "$theme_file" ]]; then
        echo "$theme_file"
        return 0
    fi

    # Check if it's a full path
    if [[ -f "$theme_name" ]]; then
        echo "$theme_name"
        return 0
    fi

    return 1
}

## Get a value from theme YAML
## Usage: theme_get <theme_file> <path> [default]
theme_get() {
    local theme_file="$1"
    local path="$2"
    local default="${3:-}"

    if [[ ! -f "$theme_file" ]]; then
        echo "$default"
        return
    fi

    local value
    value=$(yq_get "$theme_file" "$path")

    if [[ -z "$value" || "$value" == "null" ]]; then
        echo "$default"
    else
        echo "$value"
    fi
}

## Load a theme and export its colors as variables
## Usage: load_theme <theme_name>
## Sets: THEME_* variables
load_theme() {
    local theme_name="$1"
    local theme_file

    theme_file=$(get_theme_path "$theme_name") || {
        log_error "Theme not found: $theme_name"
        return 1
    }

    log_debug "Loading theme: $theme_name from $theme_file"

    # Export theme metadata
    export THEME_NAME
    export THEME_DESCRIPTION
    THEME_NAME=$(theme_get "$theme_file" ".name" "$theme_name")
    THEME_DESCRIPTION=$(theme_get "$theme_file" ".description" "")

    # Export colors
    export THEME_BG THEME_FG THEME_ACCENT THEME_ACCENT2
    export THEME_WARNING THEME_ERROR THEME_SUCCESS
    export THEME_COMMENT THEME_SELECTION THEME_BORDER

    THEME_BG=$(theme_get "$theme_file" ".colors.bg" "#1a1a2e")
    THEME_FG=$(theme_get "$theme_file" ".colors.fg" "#e0e0e0")
    THEME_ACCENT=$(theme_get "$theme_file" ".colors.accent" "#00d9ff")
    THEME_ACCENT2=$(theme_get "$theme_file" ".colors.accent2" "#ff00ff")
    THEME_WARNING=$(theme_get "$theme_file" ".colors.warning" "#ffcc00")
    THEME_ERROR=$(theme_get "$theme_file" ".colors.error" "#ff3333")
    THEME_SUCCESS=$(theme_get "$theme_file" ".colors.success" "#00ff88")
    THEME_COMMENT=$(theme_get "$theme_file" ".colors.comment" "#666666")
    THEME_SELECTION=$(theme_get "$theme_file" ".colors.selection" "#333355")
    THEME_BORDER=$(theme_get "$theme_file" ".colors.border" "#444466")

    # Export separators
    export THEME_SEP_LEFT THEME_SEP_RIGHT THEME_SEP_LEFT_ALT THEME_SEP_RIGHT_ALT
    THEME_SEP_LEFT=$(theme_get "$theme_file" ".separators.left" "")
    THEME_SEP_RIGHT=$(theme_get "$theme_file" ".separators.right" "")
    THEME_SEP_LEFT_ALT=$(theme_get "$theme_file" ".separators.left_alt" "")
    THEME_SEP_RIGHT_ALT=$(theme_get "$theme_file" ".separators.right_alt" "")

    # Export icons (with fallbacks for non-nerd-font terminals)
    export THEME_ICON_SESSION THEME_ICON_WINDOW THEME_ICON_PANE
    export THEME_ICON_GIT THEME_ICON_TIME THEME_ICON_CPU THEME_ICON_MEMORY

    THEME_ICON_SESSION=$(theme_get "$theme_file" ".icons.session" "")
    THEME_ICON_WINDOW=$(theme_get "$theme_file" ".icons.window" "")
    THEME_ICON_PANE=$(theme_get "$theme_file" ".icons.pane" "")
    THEME_ICON_GIT=$(theme_get "$theme_file" ".icons.git" "")
    THEME_ICON_TIME=$(theme_get "$theme_file" ".icons.time" "")
    THEME_ICON_CPU=$(theme_get "$theme_file" ".icons.cpu" "")
    THEME_ICON_MEMORY=$(theme_get "$theme_file" ".icons.memory" "")

    log_verbose "Loaded theme: $THEME_NAME"
    return 0
}

## Generate tmux theme configuration
## Usage: generate_theme_config <theme_name>
## Outputs tmux configuration lines for the theme
generate_theme_config() {
    local theme_name="$1"

    # Load theme variables
    load_theme "$theme_name" || return 1

    cat << EOF

# =============================================================================
# Theme: ${THEME_NAME}
# ${THEME_DESCRIPTION}
# =============================================================================

# Colors
set -g @theme-bg "${THEME_BG}"
set -g @theme-fg "${THEME_FG}"
set -g @theme-accent "${THEME_ACCENT}"
set -g @theme-accent2 "${THEME_ACCENT2}"

# Pane borders
set -g pane-border-style "fg=${THEME_BORDER}"
set -g pane-active-border-style "fg=${THEME_ACCENT}"

# Message style
set -g message-style "fg=${THEME_BG},bg=${THEME_ACCENT},bold"
set -g message-command-style "fg=${THEME_ACCENT},bg=${THEME_BG}"

# Mode style (copy mode, etc.)
set -g mode-style "fg=${THEME_BG},bg=${THEME_ACCENT}"

# Status bar base style
set -g status-style "fg=${THEME_FG},bg=${THEME_BG}"

# Window status
set -g window-status-style "fg=${THEME_COMMENT},bg=${THEME_BG}"
set -g window-status-format " #I:#W "

# Current window
set -g window-status-current-style "fg=${THEME_BG},bg=${THEME_ACCENT},bold"
set -g window-status-current-format "${THEME_SEP_LEFT}#[fg=${THEME_BG},bg=${THEME_ACCENT},bold] #I:#W #[fg=${THEME_ACCENT},bg=${THEME_BG}]${THEME_SEP_LEFT}"

# Window with activity
set -g window-status-activity-style "fg=${THEME_WARNING},bg=${THEME_BG}"

# Window bell
set -g window-status-bell-style "fg=${THEME_ERROR},bg=${THEME_BG},bold"

# Last window
set -g window-status-last-style "fg=${THEME_ACCENT2},bg=${THEME_BG}"

# Status left
set -g status-left "#[fg=${THEME_BG},bg=${THEME_ACCENT},bold] ${THEME_ICON_SESSION} #S #[fg=${THEME_ACCENT},bg=${THEME_ACCENT2}]${THEME_SEP_LEFT}#[fg=${THEME_BG},bg=${THEME_ACCENT2}] ${THEME_ICON_WINDOW} #I:#P #[fg=${THEME_ACCENT2},bg=${THEME_BG}]${THEME_SEP_LEFT} "

# Note: status-right is generated by lib/status.sh to include monitoring scripts

# Pane number display
set -g display-panes-colour "${THEME_COMMENT}"
set -g display-panes-active-colour "${THEME_ACCENT}"

# Clock
set -g clock-mode-colour "${THEME_ACCENT}"
set -g clock-mode-style 24

EOF
}

## Apply a theme to the current tmux session
## Usage: apply_theme <theme_name>
apply_theme() {
    local theme_name="$1"
    local temp_conf

    if ! is_inside_tmux; then
        log_warn "Not inside tmux, cannot apply theme directly"
        log_info "Theme will be applied on next tmux start"
        return 0
    fi

    temp_conf=$(mktemp)

    if generate_theme_config "$theme_name" > "$temp_conf"; then
        tmux source-file "$temp_conf"
        rm -f "$temp_conf"
        log_success "Applied theme: $theme_name"
    else
        rm -f "$temp_conf"
        log_error "Failed to apply theme: $theme_name"
        return 1
    fi
}

## Preview theme colors in terminal
## Usage: preview_theme <theme_name>
preview_theme() {
    local theme_name="$1"

    load_theme "$theme_name" || return 1

    echo ""
    echo -e "${BOLD}Theme: ${THEME_NAME}${RESET}"
    echo -e "${DIM}${THEME_DESCRIPTION}${RESET}"
    echo ""

    # Show color swatches
    printf "  %-12s" "Background:"
    printf "\033[48;2;%d;%d;%dm    \033[0m" \
        $((16#${THEME_BG:1:2})) \
        $((16#${THEME_BG:3:2})) \
        $((16#${THEME_BG:5:2}))
    echo " ${THEME_BG}"

    printf "  %-12s" "Foreground:"
    printf "\033[48;2;%d;%d;%dm    \033[0m" \
        $((16#${THEME_FG:1:2})) \
        $((16#${THEME_FG:3:2})) \
        $((16#${THEME_FG:5:2}))
    echo " ${THEME_FG}"

    printf "  %-12s" "Accent:"
    printf "\033[48;2;%d;%d;%dm    \033[0m" \
        $((16#${THEME_ACCENT:1:2})) \
        $((16#${THEME_ACCENT:3:2})) \
        $((16#${THEME_ACCENT:5:2}))
    echo " ${THEME_ACCENT}"

    printf "  %-12s" "Accent2:"
    printf "\033[48;2;%d;%d;%dm    \033[0m" \
        $((16#${THEME_ACCENT2:1:2})) \
        $((16#${THEME_ACCENT2:3:2})) \
        $((16#${THEME_ACCENT2:5:2}))
    echo " ${THEME_ACCENT2}"

    printf "  %-12s" "Warning:"
    printf "\033[48;2;%d;%d;%dm    \033[0m" \
        $((16#${THEME_WARNING:1:2})) \
        $((16#${THEME_WARNING:3:2})) \
        $((16#${THEME_WARNING:5:2}))
    echo " ${THEME_WARNING}"

    printf "  %-12s" "Error:"
    printf "\033[48;2;%d;%d;%dm    \033[0m" \
        $((16#${THEME_ERROR:1:2})) \
        $((16#${THEME_ERROR:3:2})) \
        $((16#${THEME_ERROR:5:2}))
    echo " ${THEME_ERROR}"

    echo ""
    echo "  Separators: ${THEME_SEP_LEFT} ${THEME_SEP_RIGHT}"
    echo ""
}
