#!/usr/bin/env bash
# pimpmytmux - Theme and layout preview functions
# https://github.com/christopherlouet/pimpmytmux

# Guard against re-sourcing
[[ -n "${_PIMPMYTMUX_PREVIEW_LOADED:-}" ]] && return 0
_PIMPMYTMUX_PREVIEW_LOADED=1

# shellcheck source=lib/core.sh
source "${PIMPMYTMUX_LIB_DIR:-$(dirname "${BASH_SOURCE[0]}")}/core.sh"

# -----------------------------------------------------------------------------
# Constants
# -----------------------------------------------------------------------------

PIMPMYTMUX_THEMES_DIR="${PIMPMYTMUX_THEMES_DIR:-${PIMPMYTMUX_ROOT}/themes}"
PIMPMYTMUX_TEMPLATES_DIR="${PIMPMYTMUX_TEMPLATES_DIR:-${PIMPMYTMUX_ROOT}/templates}"

# -----------------------------------------------------------------------------
# Color Utilities
# -----------------------------------------------------------------------------

## Convert hex color to RGB
## Usage: hex_to_rgb "#ff0000" -> "255;0;0"
hex_to_rgb() {
    local hex="$1"
    hex="${hex#\#}"  # Remove leading #

    # Handle short hex (#f00 -> #ff0000)
    if [[ ${#hex} -eq 3 ]]; then
        hex="${hex:0:1}${hex:0:1}${hex:1:1}${hex:1:1}${hex:2:1}${hex:2:1}"
    fi

    local r g b
    r=$((16#${hex:0:2}))
    g=$((16#${hex:2:2}))
    b=$((16#${hex:4:2}))

    echo "${r};${g};${b}"
}

## Create ANSI escape code for RGB color
## Usage: rgb_to_ansi 255 0 0 -> escape code for red
rgb_to_ansi() {
    local r="$1" g="$2" b="$3"
    echo "\\033[48;2;${r};${g};${b}m"
}

## Print a colored swatch block
## Usage: print_color_swatch "#ff0000" "color_name"
print_color_swatch() {
    local hex="$1"
    local name="$2"
    local rgb
    rgb=$(hex_to_rgb "$hex")

    local r g b
    IFS=';' read -r r g b <<< "$rgb"

    # Use true color ANSI codes
    echo -e "\033[48;2;${r};${g};${b}m    \033[0m ${name}: ${hex}"
}

## Print a colored text
## Usage: print_colored_text "#ff0000" "text"
print_colored_text() {
    local hex="$1"
    local text="$2"
    local rgb
    rgb=$(hex_to_rgb "$hex")

    local r g b
    IFS=';' read -r r g b <<< "$rgb"

    echo -e "\033[38;2;${r};${g};${b}m${text}\033[0m"
}

# -----------------------------------------------------------------------------
# Theme File Utilities
# -----------------------------------------------------------------------------

## Get theme file path from name or path
## Usage: get_theme_file "cyberpunk" -> /path/to/themes/cyberpunk.yaml
get_theme_file() {
    local theme="$1"

    # If it's already a path, return as-is
    if [[ "$theme" == */* || "$theme" == *.yaml ]]; then
        echo "$theme"
        return 0
    fi

    # Look in themes directory
    local theme_file="${PIMPMYTMUX_THEMES_DIR}/${theme}.yaml"
    echo "$theme_file"
}

## Get colors from a theme file
## Usage: get_theme_colors "cyberpunk"
get_theme_colors() {
    local theme="$1"
    local theme_file
    theme_file=$(get_theme_file "$theme")

    if [[ ! -f "$theme_file" ]]; then
        log_error "Theme not found: $theme"
        return 1
    fi

    require_yq

    # Extract all colors as key=value pairs
    yq eval '.colors | to_entries | .[] | .key + "=" + .value' "$theme_file" 2>/dev/null
}

## Get a specific color from theme
## Usage: get_theme_color "cyberpunk" "accent"
get_theme_color() {
    local theme="$1"
    local color_name="$2"
    local theme_file
    theme_file=$(get_theme_file "$theme")

    if [[ ! -f "$theme_file" ]]; then
        return 1
    fi

    require_yq
    yq eval ".colors.${color_name}" "$theme_file" 2>/dev/null
}

## Get theme metadata
## Usage: get_theme_info "cyberpunk" ".name"
get_theme_info() {
    local theme="$1"
    local field="$2"
    local theme_file
    theme_file=$(get_theme_file "$theme")

    if [[ ! -f "$theme_file" ]]; then
        return 1
    fi

    require_yq
    yq eval "$field" "$theme_file" 2>/dev/null
}

# -----------------------------------------------------------------------------
# Theme Preview Functions
# -----------------------------------------------------------------------------

## Preview theme colors as swatches
## Usage: preview_theme_colors "cyberpunk"
preview_theme_colors() {
    local theme="$1"
    local theme_file
    theme_file=$(get_theme_file "$theme")

    if [[ ! -f "$theme_file" ]]; then
        log_error "Theme not found: $theme"
        return 1
    fi

    echo -e "${BOLD}Colors:${RESET}"
    echo ""

    local colors
    colors=$(get_theme_colors "$theme")

    while IFS='=' read -r name hex; do
        [[ -z "$name" ]] && continue
        print_color_swatch "$hex" "$name"
    done <<< "$colors"
}

## Preview theme palette in a nice grid
## Usage: preview_theme_palette "cyberpunk"
preview_theme_palette() {
    local theme="$1"
    local theme_file
    theme_file=$(get_theme_file "$theme")

    if [[ ! -f "$theme_file" ]]; then
        log_error "Theme not found: $theme"
        return 1
    fi

    local bg fg accent accent2
    bg=$(get_theme_color "$theme" "bg")
    fg=$(get_theme_color "$theme" "fg")
    accent=$(get_theme_color "$theme" "accent")
    accent2=$(get_theme_color "$theme" "accent2")

    echo -e "${BOLD}Palette:${RESET}"
    echo ""

    # Main colors row
    local rgb_bg rgb_fg rgb_accent rgb_accent2
    rgb_bg=$(hex_to_rgb "$bg")
    rgb_fg=$(hex_to_rgb "$fg")
    rgb_accent=$(hex_to_rgb "$accent")
    rgb_accent2=$(hex_to_rgb "$accent2")

    local r g b

    # Background + Foreground
    IFS=';' read -r r g b <<< "$rgb_bg"
    echo -ne "\033[48;2;${r};${g};${b}m"
    IFS=';' read -r r g b <<< "$rgb_fg"
    echo -ne "\033[38;2;${r};${g};${b}m  Text on BG  \033[0m "

    # Accent colors
    IFS=';' read -r r g b <<< "$rgb_accent"
    echo -ne "\033[48;2;${r};${g};${b}m  accent  \033[0m "

    IFS=';' read -r r g b <<< "$rgb_accent2"
    echo -ne "\033[48;2;${r};${g};${b}m  accent2  \033[0m"
    echo ""
}

## Preview simulated status bar
## Usage: preview_theme_statusbar "cyberpunk"
preview_theme_statusbar() {
    local theme="$1"
    local theme_file
    theme_file=$(get_theme_file "$theme")

    if [[ ! -f "$theme_file" ]]; then
        log_error "Theme not found: $theme"
        return 1
    fi

    local bg accent accent2 fg
    bg=$(get_theme_color "$theme" "bg")
    fg=$(get_theme_color "$theme" "fg")
    accent=$(get_theme_color "$theme" "accent")
    accent2=$(get_theme_color "$theme" "accent2")

    echo -e "${BOLD}Status bar preview:${RESET}"
    echo ""

    local rgb r g b

    # Simulated status bar
    rgb=$(hex_to_rgb "$accent")
    IFS=';' read -r r g b <<< "$rgb"
    echo -ne "\033[48;2;${r};${g};${b}m\033[38;2;0;0;0m  main  \033[0m"

    rgb=$(hex_to_rgb "$bg")
    IFS=';' read -r r g b <<< "$rgb"
    local rgb_fg
    rgb_fg=$(hex_to_rgb "$fg")
    local rf gf bf
    IFS=';' read -r rf gf bf <<< "$rgb_fg"
    echo -ne "\033[48;2;${r};${g};${b}m\033[38;2;${rf};${gf};${bf}m  0:bash  1:vim  2:server  \033[0m"

    rgb=$(hex_to_rgb "$accent2")
    IFS=';' read -r r g b <<< "$rgb"
    echo -e "\033[48;2;${r};${g};${b}m\033[38;2;0;0;0m  12:34  \033[0m"
}

## Complete theme preview
## Usage: preview_theme "cyberpunk"
preview_theme() {
    local theme="$1"
    local theme_file
    theme_file=$(get_theme_file "$theme")

    if [[ ! -f "$theme_file" ]]; then
        log_error "Theme not found: $theme"
        return 1
    fi

    local name description
    name=$(get_theme_info "$theme" ".name")
    description=$(get_theme_info "$theme" ".description")

    echo ""
    echo -e "${BOLD}Theme: ${name}${RESET}"
    echo -e "${DIM}${description}${RESET}"
    echo ""
    echo "─────────────────────────────────────────────"
    echo ""

    preview_theme_palette "$theme"
    echo ""
    preview_theme_statusbar "$theme"
    echo ""
    preview_theme_colors "$theme"
}

# -----------------------------------------------------------------------------
# Layout File Utilities
# -----------------------------------------------------------------------------

## Get layout file path from name or path
## Usage: get_layout_file "dev-fullstack" -> /path/to/templates/dev-fullstack.yaml
get_layout_file() {
    local layout="$1"

    # If it's already a path, return as-is
    if [[ "$layout" == */* || "$layout" == *.yaml ]]; then
        echo "$layout"
        return 0
    fi

    # Look in templates directory
    local layout_file="${PIMPMYTMUX_TEMPLATES_DIR}/${layout}.yaml"
    echo "$layout_file"
}

## Get layout metadata
## Usage: get_layout_info "dev-fullstack" ".name"
get_layout_info() {
    local layout="$1"
    local field="$2"
    local layout_file
    layout_file=$(get_layout_file "$layout")

    if [[ ! -f "$layout_file" ]]; then
        return 1
    fi

    require_yq
    yq eval "$field" "$layout_file" 2>/dev/null
}

# -----------------------------------------------------------------------------
# Layout Preview Functions
# -----------------------------------------------------------------------------

## Preview layout as ASCII diagram
## Usage: preview_layout_ascii "dev-fullstack"
preview_layout_ascii() {
    local layout="$1"
    local layout_file
    layout_file=$(get_layout_file "$layout")

    if [[ ! -f "$layout_file" ]]; then
        log_error "Layout not found: $layout"
        return 1
    fi

    local orientation
    orientation=$(get_layout_info "$layout" ".layout.orientation")

    echo -e "${BOLD}Layout:${RESET}"
    echo ""

    # Generate ASCII based on layout structure
    # This is a simplified representation
    case "$layout" in
        dev-fullstack)
            cat << 'EOF'
┌────────────────────┬───────────────────┐
│                    │    terminal       │
│      editor        ├───────────────────┤
│       (60%)        │    server         │
│                    │                   │
└────────────────────┴───────────────────┘
EOF
            ;;
        dev-api)
            cat << 'EOF'
┌────────────────────────────┬───────────┐
│                            │           │
│          code              │   logs    │
│          (70%)             │   (30%)   │
│                            │           │
└────────────────────────────┴───────────┘
EOF
            ;;
        monitoring)
            cat << 'EOF'
┌───────────────────┬───────────────────┐
│      btop         │   disk/memory     │
├───────────────────┼───────────────────┤
│      logs         │     network       │
└───────────────────┴───────────────────┘
EOF
            ;;
        writing)
            cat << 'EOF'
┌─────────────────────────────────────────┐
│                                         │
│           single pane                   │
│         (zen mode enabled)              │
│                                         │
└─────────────────────────────────────────┘
EOF
            ;;
        *)
            # Generic horizontal or vertical
            if [[ "$orientation" == "horizontal" ]]; then
                cat << 'EOF'
┌───────────────────┬───────────────────┐
│                   │                   │
│      pane 1       │      pane 2       │
│                   │                   │
└───────────────────┴───────────────────┘
EOF
            else
                cat << 'EOF'
┌─────────────────────────────────────────┐
│               pane 1                    │
├─────────────────────────────────────────┤
│               pane 2                    │
└─────────────────────────────────────────┘
EOF
            fi
            ;;
    esac
}

## Preview layout details
## Usage: preview_layout_details "dev-fullstack"
preview_layout_details() {
    local layout="$1"
    local layout_file
    layout_file=$(get_layout_file "$layout")

    if [[ ! -f "$layout_file" ]]; then
        log_error "Layout not found: $layout"
        return 1
    fi

    local name description
    name=$(get_layout_info "$layout" ".name")
    description=$(get_layout_info "$layout" ".description")

    echo -e "${BOLD}Name:${RESET} $name"
    echo -e "${BOLD}Description:${RESET} $description"
}

## List panes in a layout
## Usage: preview_layout_panes "dev-fullstack"
preview_layout_panes() {
    local layout="$1"
    local layout_file
    layout_file=$(get_layout_file "$layout")

    if [[ ! -f "$layout_file" ]]; then
        log_error "Layout not found: $layout"
        return 1
    fi

    echo -e "${BOLD}Panes:${RESET}"

    require_yq

    # Extract pane names and commands
    local panes
    panes=$(yq eval '.layout.panes[].name // "unnamed"' "$layout_file" 2>/dev/null)

    local i=1
    while IFS= read -r pane_name; do
        [[ -z "$pane_name" ]] && continue
        local cmd
        cmd=$(yq eval ".layout.panes[$((i-1))].command // \"\"" "$layout_file" 2>/dev/null)
        if [[ -n "$cmd" && "$cmd" != "null" && "$cmd" != '""' ]]; then
            echo "  $i. ${pane_name}: ${cmd}"
        else
            echo "  $i. ${pane_name}"
        fi
        ((i++))
    done <<< "$panes"
}

## Complete layout preview
## Usage: preview_layout "dev-fullstack"
preview_layout() {
    local layout="$1"
    local layout_file
    layout_file=$(get_layout_file "$layout")

    if [[ ! -f "$layout_file" ]]; then
        log_error "Layout not found: $layout"
        return 1
    fi

    echo ""
    preview_layout_details "$layout"
    echo ""
    echo "─────────────────────────────────────────────"
    echo ""
    preview_layout_ascii "$layout"
    echo ""
    preview_layout_panes "$layout"
}

# -----------------------------------------------------------------------------
# Config Diff Preview
# -----------------------------------------------------------------------------

## Show diff between new config and current
## Usage: preview_config_diff "new_config.yaml"
preview_config_diff() {
    local new_config="$1"
    local current_config="${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml"

    echo -e "${BOLD}Configuration changes:${RESET}"
    echo ""

    if [[ ! -f "$current_config" ]]; then
        echo -e "${GREEN}New configuration (no existing config)${RESET}"
        echo ""
        cat "$new_config"
        return 0
    fi

    # Use diff if available
    if check_command diff; then
        if check_command colordiff; then
            diff -u "$current_config" "$new_config" | colordiff || true
        else
            # Manual coloring
            diff -u "$current_config" "$new_config" 2>/dev/null | while IFS= read -r line; do
                case "$line" in
                    +*) echo -e "${GREEN}${line}${RESET}" ;;
                    -*) echo -e "${RED}${line}${RESET}" ;;
                    @*) echo -e "${CYAN}${line}${RESET}" ;;
                    *)  echo "$line" ;;
                esac
            done || true
        fi
    else
        echo "diff command not available, showing new config:"
        echo ""
        cat "$new_config"
    fi
}

## Preview generated tmux.conf changes
## Usage: preview_tmux_conf_diff "generated_config"
preview_tmux_conf_diff() {
    local new_conf="$1"
    local current_conf
    current_conf=$(get_tmux_conf_path)

    echo -e "${BOLD}tmux.conf changes:${RESET}"
    echo ""

    if [[ ! -f "$current_conf" ]]; then
        echo -e "${GREEN}New tmux.conf (no existing file)${RESET}"
        return 0
    fi

    # Count changes
    local added removed
    added=$(diff "$current_conf" "$new_conf" 2>/dev/null | grep -c "^>" || echo "0")
    removed=$(diff "$current_conf" "$new_conf" 2>/dev/null | grep -c "^<" || echo "0")

    echo -e "Lines added:   ${GREEN}+${added}${RESET}"
    echo -e "Lines removed: ${RED}-${removed}${RESET}"
}
