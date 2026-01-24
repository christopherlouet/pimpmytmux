#!/usr/bin/env bash
# pimpmytmux - Layout templates
# Apply predefined window layouts

# Guard against re-sourcing
[[ -n "${_PIMPMYTMUX_LAYOUTS_LOADED:-}" ]] && return 0
_PIMPMYTMUX_LAYOUTS_LOADED=1

# shellcheck source=lib/core.sh
source "${PIMPMYTMUX_LIB_DIR:-$(dirname "${BASH_SOURCE[0]}")/../../lib}/core.sh"
# shellcheck source=lib/wizard.sh
source "${PIMPMYTMUX_LIB_DIR:-$(dirname "${BASH_SOURCE[0]}")/../../lib}/wizard.sh"
# shellcheck source=lib/config.sh
source "${PIMPMYTMUX_LIB_DIR:-$(dirname "${BASH_SOURCE[0]}")/../../lib}/config.sh"

# -----------------------------------------------------------------------------
# Templates directory
# -----------------------------------------------------------------------------

PIMPMYTMUX_TEMPLATES_DIR="${PIMPMYTMUX_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}/templates"

# -----------------------------------------------------------------------------
# Layout settings (globals for current layout)
# -----------------------------------------------------------------------------

LAYOUT_ZEN_MODE="false"

# -----------------------------------------------------------------------------
# Layout settings functions
# -----------------------------------------------------------------------------

## Parse settings from a layout YAML file
## Sets global variable: LAYOUT_ZEN_MODE
_parse_layout_settings() {
    local layout_file="$1"

    # Reset to default
    LAYOUT_ZEN_MODE="false"

    if [[ ! -f "$layout_file" ]]; then
        return 0
    fi

    # Extract zen_mode from YAML
    local zen_mode

    if check_command yq; then
        zen_mode=$(yq eval '.settings.zen_mode | select(. != null)' "$layout_file" 2>/dev/null)
    else
        # Fallback: simple grep-based extraction
        zen_mode=$(grep -E "^\s*zen_mode:" "$layout_file" 2>/dev/null | head -1 | sed 's/.*zen_mode:[[:space:]]*//' | tr -d ' ')
    fi

    # Set global (normalize to true/false)
    if [[ "$zen_mode" == "true" ]]; then
        LAYOUT_ZEN_MODE="true"
    else
        LAYOUT_ZEN_MODE="false"
    fi
}

## Confirm layout application when it will close panes
## Returns: 0 if confirmed or no confirmation needed, 1 if cancelled
_confirm_layout_apply() {
    local layout_name="$1"
    local pane_count

    pane_count=$(tmux display-message -p '#{window_panes}' 2>/dev/null || echo "1")

    if [[ "$pane_count" -gt 1 ]]; then
        local confirm
        confirm=$(_wizard_confirm "Layout '$layout_name' will close $((pane_count - 1)) pane(s). Continue?")
        [[ "$confirm" == "true" ]] && return 0 || return 1
    fi

    return 0
}

## Apply layout settings (zen mode)
## zen_mode: true = hide status bar + hide pane borders (distraction-free)
_apply_layout_settings() {
    if [[ "$LAYOUT_ZEN_MODE" == "true" ]]; then
        # Zen mode: hide everything for distraction-free experience
        tmux set -g status off 2>/dev/null || true
        tmux set -g pane-border-status off 2>/dev/null || true
        tmux set -g pane-border-lines hidden 2>/dev/null || true
        log_info "Zen mode enabled (status bar and borders hidden)"
    else
        # Normal mode: restore status bar and borders
        tmux set -g status on 2>/dev/null || true
        tmux set -g pane-border-lines single 2>/dev/null || true
    fi
}

## Toggle zen mode (visual only - no pane changes)
## Usage: zen_toggle [on|off]
zen_toggle() {
    local action="${1:-}"

    # Determine current state if no action specified
    if [[ -z "$action" ]]; then
        local current_status
        current_status=$(tmux show -gv status 2>/dev/null || echo "on")
        if [[ "$current_status" == "off" ]]; then
            action="off"  # Currently zen, turn it off
        else
            action="on"   # Currently normal, turn zen on
        fi
    fi

    case "$action" in
        on|true|1)
            tmux set -g status off 2>/dev/null || true
            tmux set -g pane-border-status off 2>/dev/null || true
            tmux set -g pane-border-lines hidden 2>/dev/null || true
            log_success "Zen mode enabled"
            # Note: notification won't show since status bar is off
            ;;
        off|false|0)
            tmux set -g status on 2>/dev/null || true
            tmux set -g pane-border-lines single 2>/dev/null || true
            log_success "Zen mode disabled"
            tmux_notify "Zen mode disabled" "info"
            ;;
        *)
            log_error "Invalid action: $action (use on/off)"
            return 1
            ;;
    esac
}

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

## Apply monitoring layout: 4 panes (2x2 grid)
## Top-left: htop, Bottom-left: logs, Top-right: disk/memory stats, Bottom-right: network
apply_layout_monitoring() {
    local cwd="${1:-$(pwd)}"

    # Get the current pane as base
    local base_pane
    base_pane=$(tmux display-message -p '#{pane_id}')

    # Create 2x2 grid and send commands immediately after each split
    # Pane 0 (current): top-left - htop (fallback to top)
    tmux send-keys -t "$base_pane" "htop 2>/dev/null || top" Enter

    # Split right: top-right - disk/memory stats (duf preferred, fallback to df)
    # Use while loop for TTY (colors), cursor home + clear-to-end to avoid flash
    # Hide snap/squashfs bind mounts with --hide-mp
    # Colorize free output: header=cyan, Mem=green, Swap=magenta
    tmux split-window -h -c "$cwd"
    tmux send-keys "command -v duf >/dev/null && { clear; while true; do printf '\\033[H'; duf --only local --hide-mp '/var/snap/*,/snap/*'; echo; free -h | sed -e '1s/.*/\\x1b[1;36m&\\x1b[0m/' -e 's/^Mem:/\\x1b[1;32mMem:\\x1b[0m/' -e 's/^Swap:/\\x1b[1;35mSwap:\\x1b[0m/' -e 's/^Échange:/\\x1b[1;35mÉchange:\\x1b[0m/'; printf '\\033[0J'; sleep 2; done; } || watch -t -n 2 'df -h -x tmpfs -x devtmpfs -x squashfs; echo; free -h'" Enter

    # Split down from top-right: bottom-right - network (colorized ss)
    # Use \033[H to move cursor home (no flicker) instead of clear
    tmux split-window -v -c "$cwd"
    tmux send-keys "clear; while true; do printf '\\033[H\\033[1;36m=== Network Connections ===\\033[0m\\033[K\\n'; ss -tulnp 2>/dev/null | sed 's/LISTEN/\\x1b[32mLISTEN\\x1b[0m/g; s/UNCONN/\\x1b[33mUNCONN\\x1b[0m/g; s/ESTAB/\\x1b[34mESTAB\\x1b[0m/g'; sleep 1; done" Enter

    # Go back to top-left and split down: bottom-left - logs (colorized)
    tmux select-pane -t "$base_pane"
    tmux split-window -v -c "$cwd"
    tmux send-keys "journalctl -f 2>/dev/null | ccze -A 2>/dev/null || journalctl -f 2>/dev/null || tail -f /var/log/syslog" Enter

    # Return to top-left (htop)
    tmux select-pane -t "$base_pane"
    log_success "Applied monitoring layout"
}

## Apply writing layout: single maximized pane
apply_layout_writing() {
    local cwd="${1:-$(pwd)}"
    local layout_file="${PIMPMYTMUX_TEMPLATES_DIR}/writing.yaml"

    # 1. Parse settings from template
    _parse_layout_settings "$layout_file"

    # 2. Confirmation before destructive action
    if ! _confirm_layout_apply "writing"; then
        log_warn "Layout application cancelled"
        return 1
    fi

    # 3. Kill other panes if any
    local pane_count
    pane_count=$(tmux display-message -p '#{window_panes}' 2>/dev/null || echo "1")

    if [[ "$pane_count" -gt 1 ]]; then
        tmux kill-pane -a  # Kill all panes except current
    fi

    # 4. Apply settings (status_bar, zen_mode)
    _apply_layout_settings

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

    # Parse settings from YAML
    _parse_layout_settings "$layout_file"

    local layout_name

    if check_command yq; then
        layout_name=$(yq eval '.name // "custom"' "$layout_file")
    else
        layout_name=$(basename "$layout_file" .yaml)
    fi

    # Convert to lowercase for matching
    layout_name=$(echo "$layout_name" | tr '[:upper:]' '[:lower:]')

    log_info "Applying layout: $layout_name"

    # Dispatch to specific layout function based on name
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
        *writing*)
            # Writing layout handles its own settings via _parse_layout_settings
            apply_layout_writing "$cwd"
            return $?
            ;;
        *)
            log_warn "Unknown layout type: $layout_name, applying tiled"
            tmux select-layout tiled
            ;;
    esac

    # Apply settings for non-writing layouts
    _apply_layout_settings
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

    # Reset settings to defaults for non-file layouts
    LAYOUT_ZEN_MODE="false"

    # Check for our custom layouts
    case "$layout_name" in
        dev-fullstack|fullstack)
            apply_layout_dev_fullstack "$cwd"
            _apply_layout_settings
            ;;
        dev-api|api)
            apply_layout_dev_api "$cwd"
            _apply_layout_settings
            ;;
        monitoring|monitor)
            apply_layout_monitoring "$cwd"
            _apply_layout_settings
            ;;
        writing)
            # Writing handles its own settings
            apply_layout_writing "$cwd"
            return $?
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
