#!/usr/bin/env bash
# pimpmytmux - IDE-like split layouts
# Provides IDE-inspired pane layouts

# Guard against re-sourcing
[[ -n "${_PIMPMYTMUX_IDE_SPLITS_LOADED:-}" ]] && return 0
_PIMPMYTMUX_IDE_SPLITS_LOADED=1

# -----------------------------------------------------------------------------
# IDE Layout functions
# -----------------------------------------------------------------------------

## Create VSCode-like layout: sidebar + main + terminal
## [sidebar 20%] [main 60%] [terminal 20%]
ide_layout_vscode() {
    local cwd="${1:-$(pwd)}"

    # Kill existing panes
    tmux kill-pane -a 2>/dev/null || true

    # Create main layout
    # First split: sidebar on left (20%)
    tmux split-window -h -p 80 -c "$cwd"

    # Second split: terminal at bottom of main area (20%)
    tmux split-window -v -p 20 -c "$cwd"

    # Select the main editor pane
    tmux select-pane -t 1

    # Label panes (if tmux >= 3.3)
    tmux select-pane -t 0 -T "sidebar" 2>/dev/null || true
    tmux select-pane -t 1 -T "editor" 2>/dev/null || true
    tmux select-pane -t 2 -T "terminal" 2>/dev/null || true

    echo "IDE layout (VSCode-style) applied"
}

## Create JetBrains-like layout: [files] [editor] | [terminal/tools]
##                              [20%  ] [50%   ] | [30%           ]
ide_layout_jetbrains() {
    local cwd="${1:-$(pwd)}"

    tmux kill-pane -a 2>/dev/null || true

    # Right panel (30%)
    tmux split-window -h -p 30 -c "$cwd"

    # Left sidebar (20% of remaining 70% = ~25% of left side)
    tmux select-pane -t 0
    tmux split-window -h -p 75 -c "$cwd"

    # Split right panel into terminal and tools
    tmux select-pane -t 2
    tmux split-window -v -p 50 -c "$cwd"

    # Select editor pane
    tmux select-pane -t 1

    echo "IDE layout (JetBrains-style) applied"
}

## Create simple two-column layout: editor | terminal
ide_layout_simple() {
    local cwd="${1:-$(pwd)}"
    local editor_percent="${2:-70}"

    tmux kill-pane -a 2>/dev/null || true

    local terminal_percent=$((100 - editor_percent))
    tmux split-window -h -p "$terminal_percent" -c "$cwd"

    tmux select-pane -t 0

    echo "Simple IDE layout (${editor_percent}/${terminal_percent}) applied"
}

## Create three-row layout: editor | output | terminal
ide_layout_stacked() {
    local cwd="${1:-$(pwd)}"

    tmux kill-pane -a 2>/dev/null || true

    # Output pane (30%)
    tmux split-window -v -p 30 -c "$cwd"

    # Terminal pane (50% of bottom = 15% of total)
    tmux split-window -v -p 50 -c "$cwd"

    tmux select-pane -t 0

    echo "Stacked IDE layout applied"
}

## Toggle sidebar (first pane)
ide_toggle_sidebar() {
    local pane_count
    pane_count=$(tmux display-message -p '#{window_panes}')

    if [[ "$pane_count" -lt 2 ]]; then
        # Create sidebar
        tmux split-window -hb -p 20
        tmux select-pane -t 1
    else
        # Check if sidebar is visible (pane 0 width)
        local pane0_width
        pane0_width=$(tmux display-message -p -t 0 '#{pane_width}')

        if [[ "$pane0_width" -gt 5 ]]; then
            # Hide sidebar (resize to minimum)
            tmux resize-pane -t 0 -x 1
        else
            # Show sidebar
            tmux resize-pane -t 0 -x 30
        fi
    fi
}

## Toggle terminal (bottom pane)
ide_toggle_terminal() {
    local pane_count
    pane_count=$(tmux display-message -p '#{window_panes}')

    if [[ "$pane_count" -lt 2 ]]; then
        # Create terminal
        tmux split-window -v -p 20
        tmux select-pane -t 0
    else
        # Find terminal pane (assume it's the last one)
        local last_pane=$((pane_count - 1))
        local pane_height
        pane_height=$(tmux display-message -p -t "$last_pane" '#{pane_height}')

        if [[ "$pane_height" -gt 3 ]]; then
            # Hide terminal
            tmux resize-pane -t "$last_pane" -y 1
        else
            # Show terminal
            tmux resize-pane -t "$last_pane" -y 15
        fi
    fi
}

# -----------------------------------------------------------------------------
# Generate IDE bindings
# -----------------------------------------------------------------------------

generate_ide_bindings() {
    local module_path="${PIMPMYTMUX_ROOT}/modules/devtools/ide-splits.sh"

    cat << EOF
# -----------------------------------------------------------------------------
# IDE Layouts
# -----------------------------------------------------------------------------

# Apply IDE layouts
bind I run-shell "source '$module_path' && ide_layout_vscode '#{pane_current_path}'"

# Toggle sidebar
bind b run-shell "source '$module_path' && ide_toggle_sidebar"

# Toggle terminal
bind t run-shell "source '$module_path' && ide_toggle_terminal"

EOF
}
