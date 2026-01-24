#!/usr/bin/env bash
# pimpmytmux - Layout templates
# Apply predefined window layouts

# Guard against re-sourcing
[[ -n "${_PIMPMYTMUX_LAYOUTS_LOADED:-}" ]] && return 0
_PIMPMYTMUX_LAYOUTS_LOADED=1

# shellcheck source=lib/core.sh
source "${PIMPMYTMUX_LIB_DIR:-$(dirname "${BASH_SOURCE[0]}")/../../lib}/core.sh"

# -----------------------------------------------------------------------------
# Templates directory
# -----------------------------------------------------------------------------

PIMPMYTMUX_TEMPLATES_DIR="${PIMPMYTMUX_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}/templates"

# -----------------------------------------------------------------------------
# Layout functions
# -----------------------------------------------------------------------------

## List available layout templates
list_layouts() {
    if [[ ! -d "$PIMPMYTMUX_TEMPLATES_DIR" ]]; then
        log_error "Templates directory not found"
        return 1
    fi

    echo "Available layouts:"
    for file in "$PIMPMYTMUX_TEMPLATES_DIR"/*.yaml; do
        if [[ -f "$file" ]]; then
            local name desc
            name=$(basename "$file" .yaml)

            if check_command yq; then
                desc=$(yq eval '.description // ""' "$file" 2>/dev/null)
            else
                desc=$(grep "^description:" "$file" | head -1 | sed 's/^description:[[:space:]]*//')
            fi

            printf "  %-20s %s\n" "$name" "$desc"
        fi
    done
}

## Get layout template path
get_layout_path() {
    local layout_name="$1"
    local layout_file="${PIMPMYTMUX_TEMPLATES_DIR}/${layout_name}.yaml"

    if [[ -f "$layout_file" ]]; then
        echo "$layout_file"
        return 0
    fi

    # Check if it's a full path
    if [[ -f "$layout_name" ]]; then
        echo "$layout_name"
        return 0
    fi

    return 1
}

## Apply a layout using built-in presets
_apply_preset_layout() {
    local preset="$1"
    local target="${2:-}"

    case "$preset" in
        main-horizontal)
            tmux select-layout main-horizontal
            ;;
        main-vertical)
            tmux select-layout main-vertical
            ;;
        tiled)
            tmux select-layout tiled
            ;;
        even-horizontal)
            tmux select-layout even-horizontal
            ;;
        even-vertical)
            tmux select-layout even-vertical
            ;;
        *)
            return 1
            ;;
    esac
}

## Apply dev-fullstack layout: editor (60%) | terminal + server
apply_layout_dev_fullstack() {
    local cwd="${1:-$(pwd)}"

    # Create the layout in current window or new window
    tmux split-window -h -p 40 -c "$cwd"
    tmux split-window -v -p 50 -c "$cwd"

    # Go back to first pane (editor)
    tmux select-pane -t 0

    # Send commands if EDITOR is set
    if [[ -n "${EDITOR:-}" ]]; then
        tmux send-keys -t 0 "${EDITOR} ." Enter
    fi

    log_success "Applied dev-fullstack layout"
}

## Apply dev-api layout: code (70%) | logs
apply_layout_dev_api() {
    local cwd="${1:-$(pwd)}"

    tmux split-window -h -p 30 -c "$cwd"

    # Editor in main pane
    tmux select-pane -t 0
    if [[ -n "${EDITOR:-}" ]]; then
        tmux send-keys -t 0 "${EDITOR} ." Enter
    fi

    log_success "Applied dev-api layout"
}

## Apply monitoring layout: 4 panes
apply_layout_monitoring() {
    local cwd="${1:-$(pwd)}"

    # Create 2x2 grid
    tmux split-window -h -c "$cwd"
    tmux split-window -v -c "$cwd"
    tmux select-pane -t 0
    tmux split-window -v -c "$cwd"

    # Optionally start monitoring tools
    tmux send-keys -t 0 "htop 2>/dev/null || top" Enter
    tmux send-keys -t 2 "echo 'Logs pane - tail -f your-log-file'" Enter

    tmux select-pane -t 0
    log_success "Applied monitoring layout"
}

## Apply writing layout: single maximized pane
apply_layout_writing() {
    # Just ensure we're in a clean single pane
    # Kill other panes if any
    local pane_count
    pane_count=$(tmux display-message -p '#{window_panes}')

    if [[ "$pane_count" -gt 1 ]]; then
        log_warn "Killing other panes for zen mode"
        tmux kill-pane -a  # Kill all panes except current
    fi

    log_success "Applied writing (zen) layout"
}

## Apply a layout from template file
apply_layout_from_file() {
    local layout_file="$1"
    local cwd="${2:-$(pwd)}"

    if [[ ! -f "$layout_file" ]]; then
        log_error "Layout file not found: $layout_file"
        return 1
    fi

    local layout_name

    if check_command yq; then
        layout_name=$(yq eval '.name // "custom"' "$layout_file")
    else
        layout_name=$(basename "$layout_file" .yaml)
    fi

    log_info "Applying layout: $layout_name"

    # For now, use predefined layouts based on name
    # TODO: Parse YAML layout definitions
    case "$layout_name" in
        *fullstack*|*full-stack*)
            apply_layout_dev_fullstack "$cwd"
            ;;
        *api*)
            apply_layout_dev_api "$cwd"
            ;;
        *monitor*)
            apply_layout_monitoring "$cwd"
            ;;
        *writing*|*zen*)
            apply_layout_writing
            ;;
        *)
            log_warn "Unknown layout type, applying tiled"
            tmux select-layout tiled
            ;;
    esac
}

## Apply a layout by name
apply_layout() {
    local layout_name="$1"
    local cwd="${2:-$(pwd)}"

    # Check for built-in tmux layouts first
    if _apply_preset_layout "$layout_name" 2>/dev/null; then
        log_success "Applied preset layout: $layout_name"
        return 0
    fi

    # Check for our custom layouts
    case "$layout_name" in
        dev-fullstack|fullstack)
            apply_layout_dev_fullstack "$cwd"
            ;;
        dev-api|api)
            apply_layout_dev_api "$cwd"
            ;;
        monitoring|monitor)
            apply_layout_monitoring "$cwd"
            ;;
        writing|zen)
            apply_layout_writing
            ;;
        *)
            # Try to find template file
            local layout_file
            if layout_file=$(get_layout_path "$layout_name"); then
                apply_layout_from_file "$layout_file" "$cwd"
            else
                log_error "Layout not found: $layout_name"
                log_info "Available layouts:"
                list_layouts
                return 1
            fi
            ;;
    esac
}

## Interactive layout chooser
choose_layout() {
    local layouts=(
        "dev-fullstack:Editor + Terminal + Server (60/40 split)"
        "dev-api:Code + Logs (70/30 split)"
        "monitoring:4 panes for system monitoring"
        "writing:Single pane zen mode"
        "tiled:Tmux tiled layout"
        "main-horizontal:Main pane on top"
        "main-vertical:Main pane on left"
    )

    local choice

    if check_command fzf; then
        choice=$(printf '%s\n' "${layouts[@]}" | fzf --prompt="Select layout: " | cut -d: -f1)
    else
        echo "Available layouts:"
        local i=1
        for l in "${layouts[@]}"; do
            printf "  %d) %s\n" "$i" "$l"
            ((i++))
        done
        read -rp "Enter number: " num
        choice=$(echo "${layouts[$((num-1))]}" | cut -d: -f1)
    fi

    if [[ -n "$choice" ]]; then
        apply_layout "$choice"
    fi
}
