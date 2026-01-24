#!/usr/bin/env bash
# pimpmytmux - Smart splits
# Intelligent pane splitting and vim-tmux-navigator integration

# Guard against re-sourcing
[[ -n "${_PIMPMYTMUX_SMART_SPLITS_LOADED:-}" ]] && return 0
_PIMPMYTMUX_SMART_SPLITS_LOADED=1

# -----------------------------------------------------------------------------
# Smart split configuration generator
# -----------------------------------------------------------------------------

## Generate smart split bindings
generate_smart_splits() {
    cat << 'EOF'
# -----------------------------------------------------------------------------
# Smart Splits
# -----------------------------------------------------------------------------

# Smart split - detect orientation based on pane dimensions
# If wider than tall, split vertically; otherwise split horizontally
bind '\' if-shell '[ $(tmux display -p "#{pane_width}") -gt $(tmux display -p "#{pane_height}") ]' \
    'split-window -h -c "#{pane_current_path}"' \
    'split-window -v -c "#{pane_current_path}"'

# Quick horizontal/vertical splits with better keys
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
bind _ split-window -v -c "#{pane_current_path}"

# Split and run command
bind S command-prompt -p "split and run:" "split-window -h '%%'"
bind V command-prompt -p "split and run:" "split-window -v '%%'"

EOF
}

## Generate vim-tmux-navigator compatible bindings
## These allow seamless navigation between tmux panes and vim splits
generate_vim_tmux_navigator() {
    cat << 'EOF'
# -----------------------------------------------------------------------------
# Vim-Tmux Navigator Integration
# -----------------------------------------------------------------------------
# Seamless navigation between tmux panes and vim splits
# Requires vim-tmux-navigator plugin in Vim/Neovim

# Check if we're in a vim/nvim process
is_vim="ps -o state= -o comm= -t '#{pane_tty}' \
    | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|l?n?vim?x?|fzf)(diff)?$'"

# Smart pane switching with awareness of Vim splits
bind -n 'C-h' if-shell "$is_vim" 'send-keys C-h'  'select-pane -L'
bind -n 'C-j' if-shell "$is_vim" 'send-keys C-j'  'select-pane -D'
bind -n 'C-k' if-shell "$is_vim" 'send-keys C-k'  'select-pane -U'
bind -n 'C-l' if-shell "$is_vim" 'send-keys C-l'  'select-pane -R'

# Previous pane (like vim's C-w p)
bind -n 'C-\' if-shell "$is_vim" 'send-keys C-\\' 'select-pane -l'

# Copy mode navigation
bind -T copy-mode-vi 'C-h' select-pane -L
bind -T copy-mode-vi 'C-j' select-pane -D
bind -T copy-mode-vi 'C-k' select-pane -U
bind -T copy-mode-vi 'C-l' select-pane -R
bind -T copy-mode-vi 'C-\' select-pane -l

EOF
}

## Generate smart zoom bindings
generate_smart_zoom() {
    cat << 'EOF'
# -----------------------------------------------------------------------------
# Smart Zoom
# -----------------------------------------------------------------------------

# Toggle zoom with z
bind z resize-pane -Z

# Zoom and break pane to new window
bind Z break-pane

# Join pane from another window
bind J command-prompt -p "join pane from:" "join-pane -s '%%'"

# Send pane to another window
bind @ command-prompt -p "send pane to:" "join-pane -t '%%'"

EOF
}

## Generate pane management bindings
generate_pane_management() {
    cat << 'EOF'
# -----------------------------------------------------------------------------
# Pane Management
# -----------------------------------------------------------------------------

# Rotate panes
bind -r o rotate-window

# Swap panes
bind -r '{' swap-pane -U
bind -r '}' swap-pane -D

# Mark and swap panes (like vim marks)
bind m select-pane -m  # Mark current pane
bind M swap-pane       # Swap with marked pane

# Spread panes evenly
bind E select-layout even-horizontal
bind e select-layout even-vertical

# Maximize/restore pane (alternative to zoom)
bind + resize-pane -Z

# Balance panes
bind = select-layout tiled

# Respawn pane (restart shell)
bind R respawn-pane -k

EOF
}

## Generate all smart split configuration
generate_smart_splits_config() {
    generate_smart_splits
    generate_vim_tmux_navigator
    generate_smart_zoom
    generate_pane_management
}
