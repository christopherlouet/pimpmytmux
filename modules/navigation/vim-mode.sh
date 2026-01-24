#!/usr/bin/env bash
# pimpmytmux - Vim-style navigation
# Adds vim keybindings for pane navigation and resizing

# Guard against re-sourcing
[[ -n "${_PIMPMYTMUX_VIM_MODE_LOADED:-}" ]] && return 0
_PIMPMYTMUX_VIM_MODE_LOADED=1

# -----------------------------------------------------------------------------
# Vim mode configuration generator
# -----------------------------------------------------------------------------

## Generate vim-style navigation bindings
generate_vim_navigation() {
    cat << 'EOF'
# -----------------------------------------------------------------------------
# Vim-style Navigation
# -----------------------------------------------------------------------------

# Pane navigation with hjkl
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# Pane navigation with arrow keys (fallback)
bind Left select-pane -L
bind Down select-pane -D
bind Up select-pane -U
bind Right select-pane -R

# Pane resizing with HJKL (repeatable)
bind -r H resize-pane -L 5
bind -r J resize-pane -D 5
bind -r K resize-pane -U 5
bind -r L resize-pane -R 5

# Fine-grained resizing with Alt+hjkl
bind -r M-h resize-pane -L 1
bind -r M-j resize-pane -D 1
bind -r M-k resize-pane -U 1
bind -r M-l resize-pane -R 1

EOF
}

## Generate vim-style copy mode bindings
generate_vim_copy_mode() {
    cat << 'EOF'
# -----------------------------------------------------------------------------
# Vim-style Copy Mode
# -----------------------------------------------------------------------------

# Use vi keys in copy mode
setw -g mode-keys vi

# Enter copy mode with prefix + [
bind [ copy-mode

# Begin selection with v
bind -T copy-mode-vi v send-keys -X begin-selection

# Rectangle selection with C-v
bind -T copy-mode-vi C-v send-keys -X rectangle-toggle

# Yank with y
bind -T copy-mode-vi y send-keys -X copy-selection-and-cancel

# Yank to end of line with Y
bind -T copy-mode-vi Y send-keys -X copy-end-of-line

# Paste with prefix + p (or ])
bind p paste-buffer
bind ] paste-buffer

# Cancel with Escape
bind -T copy-mode-vi Escape send-keys -X cancel

# Search with / and ?
bind -T copy-mode-vi / command-prompt -i -p "search down" "send -X search-forward-incremental \"%%%\""
bind -T copy-mode-vi ? command-prompt -i -p "search up" "send -X search-backward-incremental \"%%%\""

# Jump to line with g and G
bind -T copy-mode-vi g send-keys -X history-top
bind -T copy-mode-vi G send-keys -X history-bottom

# Half page up/down with C-u and C-d
bind -T copy-mode-vi C-u send-keys -X halfpage-up
bind -T copy-mode-vi C-d send-keys -X halfpage-down

# Word navigation
bind -T copy-mode-vi w send-keys -X next-word
bind -T copy-mode-vi b send-keys -X previous-word
bind -T copy-mode-vi e send-keys -X next-word-end

EOF
}

## Generate window navigation bindings
generate_vim_window_nav() {
    cat << 'EOF'
# -----------------------------------------------------------------------------
# Window Navigation (Vim-inspired)
# -----------------------------------------------------------------------------

# Quick window switching with Alt+number (without prefix)
bind -n M-1 select-window -t 1
bind -n M-2 select-window -t 2
bind -n M-3 select-window -t 3
bind -n M-4 select-window -t 4
bind -n M-5 select-window -t 5
bind -n M-6 select-window -t 6
bind -n M-7 select-window -t 7
bind -n M-8 select-window -t 8
bind -n M-9 select-window -t 9

# Previous/next window
bind -r C-h previous-window
bind -r C-l next-window

# Last window (like vim's alternate file)
bind Space last-window

# Swap windows
bind -r < swap-window -t -1 \; previous-window
bind -r > swap-window -t +1 \; next-window

EOF
}

## Generate all vim mode configuration
generate_vim_mode_config() {
    generate_vim_navigation
    generate_vim_copy_mode
    generate_vim_window_nav
}
