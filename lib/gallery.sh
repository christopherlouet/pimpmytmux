#!/usr/bin/env bash
# pimpmytmux - Theme gallery display
# https://github.com/christopherlouet/pimpmytmux

# Guard against re-sourcing
[[ -n "${_PIMPMYTMUX_GALLERY_LOADED:-}" ]] && return 0
_PIMPMYTMUX_GALLERY_LOADED=1

# shellcheck source=lib/core.sh
source "${PIMPMYTMUX_LIB_DIR:-$(dirname "${BASH_SOURCE[0]}")}/core.sh"
# shellcheck source=lib/preview.sh
source "${PIMPMYTMUX_LIB_DIR:-$(dirname "${BASH_SOURCE[0]}")}/preview.sh"

# -----------------------------------------------------------------------------
# Gallery Display
# -----------------------------------------------------------------------------

## Display a compact theme card
## Usage: show_theme_card "theme_name"
show_theme_card() {
    local theme="$1"
    local theme_file
    theme_file=$(get_theme_file "$theme")

    if [[ ! -f "$theme_file" ]]; then
        return 1
    fi

    local name description
    name=$(get_theme_info "$theme" ".name")
    description=$(get_theme_info "$theme" ".description")

    local bg fg accent accent2
    bg=$(get_theme_color "$theme" "bg")
    fg=$(get_theme_color "$theme" "fg")
    accent=$(get_theme_color "$theme" "accent")
    accent2=$(get_theme_color "$theme" "accent2")

    # Get RGB values
    local rgb_bg rgb_fg rgb_accent rgb_accent2
    rgb_bg=$(hex_to_rgb "$bg")
    rgb_fg=$(hex_to_rgb "$fg")
    rgb_accent=$(hex_to_rgb "$accent")
    rgb_accent2=$(hex_to_rgb "$accent2")

    local rb gb bb rf gf bf ra ga ba ra2 ga2 ba2
    IFS=';' read -r rb gb bb <<< "$rgb_bg"
    IFS=';' read -r rf gf bf <<< "$rgb_fg"
    IFS=';' read -r ra ga ba <<< "$rgb_accent"
    IFS=';' read -r ra2 ga2 ba2 <<< "$rgb_accent2"

    # Card header with theme name on background
    echo -ne "\033[48;2;${rb};${gb};${bb}m\033[38;2;${rf};${gf};${bf}m"
    printf " %-14s " "$name"
    echo -ne "\033[0m"

    # Color swatches
    echo -ne " \033[48;2;${ra};${ga};${ba}m  \033[0m"
    echo -ne "\033[48;2;${ra2};${ga2};${ba2}m  \033[0m"
    echo ""

    # Description (truncated)
    if [[ -n "$description" ]]; then
        local truncated="${description:0:40}"
        [[ ${#description} -gt 40 ]] && truncated="${truncated}..."
        echo -e "  ${DIM}${truncated}${RESET}"
    fi
}

## Display full theme gallery
## Usage: show_gallery
show_gallery() {
    local themes_dir="${PIMPMYTMUX_THEMES_DIR:-${PIMPMYTMUX_ROOT}/themes}"
    local current_theme
    current_theme=$(get_config ".theme" "")

    echo ""
    echo -e "${BOLD}Theme Gallery${RESET}"
    echo -e "${DIM}Preview all available themes${RESET}"
    echo ""
    echo "─────────────────────────────────────────────"
    echo ""

    for theme_file in "$themes_dir"/*.yaml; do
        if [[ -f "$theme_file" ]]; then
            local theme_name
            theme_name=$(basename "$theme_file" .yaml)

            # Mark current theme
            if [[ "$theme_name" == "$current_theme" ]]; then
                echo -e "${GREEN}*${RESET} Current theme:"
            fi

            show_theme_card "$theme_name"
            echo ""
        fi
    done

    echo "─────────────────────────────────────────────"
    echo ""
    echo "Apply a theme: pimpmytmux theme <name>"
    echo "Preview a theme: pimpmytmux theme <name> --preview"
}

## Interactive theme selection (requires gum)
## Usage: select_theme_interactive
select_theme_interactive() {
    if ! check_command gum; then
        log_warn "gum not installed, showing gallery instead"
        show_gallery
        return 0
    fi

    local themes_dir="${PIMPMYTMUX_THEMES_DIR:-${PIMPMYTMUX_ROOT}/themes}"
    local themes=()
    local descriptions=()

    for theme_file in "$themes_dir"/*.yaml; do
        if [[ -f "$theme_file" ]]; then
            local name desc
            name=$(basename "$theme_file" .yaml)
            desc=$(get_theme_info "$name" ".description" 2>/dev/null || echo "")
            themes+=("$name")
            descriptions+=("$desc")
        fi
    done

    echo -e "${BOLD}Select a theme:${RESET}"
    echo ""

    local selected
    selected=$(printf '%s\n' "${themes[@]}" | gum choose --header "Use arrow keys to navigate, Enter to select")

    if [[ -n "$selected" ]]; then
        echo ""
        echo "Selected: $selected"
        echo ""
        read -rp "Apply this theme? [y/N] " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            return_theme_choice "$selected"
        fi
    fi
}

## Display side-by-side theme comparison
## Usage: compare_themes "theme1" "theme2"
compare_themes() {
    local theme1="$1"
    local theme2="$2"

    echo ""
    echo -e "${BOLD}Theme Comparison${RESET}"
    echo ""
    echo "─────────────────────────────────────────────"

    # Display both themes side by side (simplified)
    echo ""
    echo -e "${BOLD}$theme1${RESET}                    ${BOLD}$theme2${RESET}"
    echo ""

    local colors1 colors2
    colors1=$(get_theme_colors "$theme1")
    colors2=$(get_theme_colors "$theme2")

    # Show key colors
    local bg1 bg2 accent1 accent2
    bg1=$(get_theme_color "$theme1" "bg")
    bg2=$(get_theme_color "$theme2" "bg")
    accent1=$(get_theme_color "$theme1" "accent")
    accent2=$(get_theme_color "$theme2" "accent")

    echo -n "Background: "
    print_color_swatch "$bg1" "    "
    echo -n "                    "
    print_color_swatch "$bg2" "    "

    echo -n "Accent:     "
    print_color_swatch "$accent1" "    "
    echo -n "                    "
    print_color_swatch "$accent2" "    "
}

## Display mini preview for all themes in grid
## Usage: show_mini_gallery
show_mini_gallery() {
    local themes_dir="${PIMPMYTMUX_THEMES_DIR:-${PIMPMYTMUX_ROOT}/themes}"
    local current_theme
    current_theme=$(get_config ".theme" "")

    echo ""
    echo -e "${BOLD}Themes${RESET}"
    echo ""

    local count=0
    for theme_file in "$themes_dir"/*.yaml; do
        if [[ -f "$theme_file" ]]; then
            local theme_name
            theme_name=$(basename "$theme_file" .yaml)

            local bg accent accent2
            bg=$(get_theme_color "$theme_name" "bg")
            accent=$(get_theme_color "$theme_name" "accent")
            accent2=$(get_theme_color "$theme_name" "accent2")

            local rgb_bg rgb_accent rgb_accent2
            rgb_bg=$(hex_to_rgb "$bg")
            rgb_accent=$(hex_to_rgb "$accent")
            rgb_accent2=$(hex_to_rgb "$accent2")

            local rb gb bb ra ga ba ra2 ga2 ba2
            IFS=';' read -r rb gb bb <<< "$rgb_bg"
            IFS=';' read -r ra ga ba <<< "$rgb_accent"
            IFS=';' read -r ra2 ga2 ba2 <<< "$rgb_accent2"

            # Color blocks
            echo -ne "\033[48;2;${rb};${gb};${bb}m \033[0m"
            echo -ne "\033[48;2;${ra};${ga};${ba}m \033[0m"
            echo -ne "\033[48;2;${ra2};${ga2};${ba2}m \033[0m"

            # Theme name
            if [[ "$theme_name" == "$current_theme" ]]; then
                echo -ne " ${GREEN}${theme_name}${RESET} *"
            else
                echo -ne " ${theme_name}"
            fi

            ((count++))
            # Two per row
            if ((count % 2 == 0)); then
                echo ""
            else
                echo -ne "\t\t"
            fi
        fi
    done

    # Ensure newline at end
    ((count % 2 != 0)) && echo ""

    echo ""
}
