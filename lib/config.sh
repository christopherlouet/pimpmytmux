#!/usr/bin/env bash
# pimpmytmux - Configuration parsing and tmux.conf generation
# https://github.com/christopherlouet/pimpmytmux

# Guard against re-sourcing
[[ -n "${_PIMPMYTMUX_CONFIG_LOADED:-}" ]] && return 0
_PIMPMYTMUX_CONFIG_LOADED=1

# shellcheck source=lib/core.sh
source "${PIMPMYTMUX_LIB_DIR:-$(dirname "${BASH_SOURCE[0]}")}/core.sh"
# shellcheck source=lib/themes.sh
source "${PIMPMYTMUX_LIB_DIR:-$(dirname "${BASH_SOURCE[0]}")}/themes.sh"
# shellcheck source=lib/status.sh
source "${PIMPMYTMUX_LIB_DIR:-$(dirname "${BASH_SOURCE[0]}")}/status.sh"

# Source navigation modules
source "${PIMPMYTMUX_ROOT}/modules/navigation/vim-mode.sh" 2>/dev/null || true
source "${PIMPMYTMUX_ROOT}/modules/navigation/fzf-integration.sh" 2>/dev/null || true
source "${PIMPMYTMUX_ROOT}/modules/navigation/smart-splits.sh" 2>/dev/null || true

# -----------------------------------------------------------------------------
# Constants
# -----------------------------------------------------------------------------

readonly DEFAULT_CONFIG_FILE="${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml"
readonly GENERATED_CONF_FILE="${PIMPMYTMUX_CONFIG_DIR}/tmux.conf"
readonly PIMPMYTMUX_ROOT="${PIMPMYTMUX_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# -----------------------------------------------------------------------------
# YAML Parsing
# -----------------------------------------------------------------------------

## Check if yq is available and which version
## Returns: "go" for Go version, "python" for Python version, "" if not found
detect_yq_version() {
    if ! check_command yq; then
        echo ""
        return
    fi

    # Go version outputs version like "yq (https://github.com/mikefarah/yq/) version v4.x.x"
    # Python version outputs like "yq 2.x.x"
    if yq --version 2>&1 | grep -q "mikefarah"; then
        echo "go"
    elif yq --version 2>&1 | grep -qE "^yq [0-9]"; then
        echo "python"
    else
        echo "go"  # Assume Go version for newer installations
    fi
}

## Require yq to be installed
## Usage: require_yq
## Exits with error if yq is not available
require_yq() {
    if ! check_command yq; then
        log_error "yq is required but not installed."
        log_error ""
        log_error "Install yq (Go version recommended):"
        log_error "  macOS:   brew install yq"
        log_error "  Linux:   sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 && sudo chmod +x /usr/local/bin/yq"
        log_error "  Snap:    sudo snap install yq"
        log_error ""
        log_error "More info: https://github.com/mikefarah/yq"
        exit 1
    fi
}

## Get a value from YAML file using yq
## Usage: yq_get <file> <path>
## Example: yq_get config.yaml '.theme'
yq_get() {
    local file="$1"
    local path="$2"

    if [[ ! -f "$file" ]]; then
        log_error "Config file not found: $file"
        return 1
    fi

    # Require yq - no fallback
    require_yq

    local yq_type
    yq_type=$(detect_yq_version)

    # Note: We use select() instead of // to properly handle false values
    # The // operator treats false as falsy, which causes issues with booleans
    case "$yq_type" in
        go)
            local result
            result=$(yq eval "$path" "$file" 2>/dev/null)
            # Handle null explicitly
            if [[ "$result" == "null" ]]; then
                echo ""
            else
                echo "$result"
            fi
            ;;
        python)
            local result
            result=$(yq -r "$path" "$file" 2>/dev/null)
            if [[ "$result" == "null" ]]; then
                echo ""
            else
                echo "$result"
            fi
            ;;
        *)
            # Should not reach here after require_yq
            log_error "yq is required for YAML parsing"
            return 1
            ;;
    esac
}

## Get a config value with default fallback
## Usage: get_config <path> [default]
get_config() {
    local path="$1"
    local default="${2:-}"
    local config_file="${PIMPMYTMUX_CONFIG_FILE:-$DEFAULT_CONFIG_FILE}"
    local value

    value=$(yq_get "$config_file" "$path")

    if [[ -z "$value" || "$value" == "null" ]]; then
        echo "$default"
    else
        echo "$value"
    fi
}

## Check if a config path is enabled (true/yes/1)
## Usage: config_enabled <path>
config_enabled() {
    local path="$1"
    local value
    value=$(get_config "$path" "false")
    value=$(to_lower "$value")

    [[ "$value" == "true" || "$value" == "yes" || "$value" == "1" ]]
}

## Get the clipboard copy command for the current platform
## Usage: get_copy_command
## Returns: The copy command (e.g., "wl-copy", "pbcopy", "xclip -selection clipboard")
##          or empty string if not configured
get_copy_command() {
    local platform
    platform=$(get_platform)

    case "$platform" in
        linux|macos|wsl)
            get_config ".platform.${platform}.copy_command" ""
            ;;
        *)
            echo ""
            ;;
    esac
}

# -----------------------------------------------------------------------------
# Config Validation
# -----------------------------------------------------------------------------

## Validate the configuration file
## Returns: 0 if valid, 1 if errors found
validate_config() {
    local config_file="${1:-$DEFAULT_CONFIG_FILE}"
    local errors=0

    if [[ ! -f "$config_file" ]]; then
        log_error "Configuration file not found: $config_file"
        return 1
    fi

    # Check YAML syntax
    local yq_type
    yq_type=$(detect_yq_version)

    if [[ "$yq_type" == "go" ]]; then
        if ! yq eval '.' "$config_file" &>/dev/null; then
            log_error "Invalid YAML syntax in $config_file"
            return 1
        fi
    fi

    # Validate theme exists
    local theme
    theme=$(get_config ".theme" "cyberpunk")
    local theme_file="${PIMPMYTMUX_ROOT}/themes/${theme}.yaml"
    if [[ ! -f "$theme_file" && ! -f "$theme" ]]; then
        log_warn "Theme not found: $theme (will use defaults)"
    fi

    # Validate prefix key format
    local prefix
    prefix=$(get_config ".general.prefix" "C-b")
    if [[ ! "$prefix" =~ ^[CM]-[a-zA-Z]$ ]]; then
        log_warn "Unusual prefix format: $prefix"
    fi

    return $errors
}

# -----------------------------------------------------------------------------
# tmux.conf Generation
# -----------------------------------------------------------------------------

## Generate the preamble for tmux.conf
_generate_preamble() {
    cat << 'EOF'
# =============================================================================
# pimpmytmux - Auto-generated tmux configuration
# DO NOT EDIT THIS FILE DIRECTLY - Edit pimpmytmux.yaml instead
# Regenerate with: pimpmytmux apply
# =============================================================================

EOF
}

## Generate general settings section
_generate_general_settings() {
    local prefix prefix2 base_index mouse history escape_time focus true_color terminal

    prefix=$(get_config ".general.prefix" "C-b")
    prefix2=$(get_config ".general.prefix2" "")
    base_index=$(get_config ".general.base_index" "1")
    mouse=$(get_config ".general.mouse" "true")
    history=$(get_config ".general.history_limit" "50000")
    escape_time=$(get_config ".general.escape_time" "10")
    focus=$(get_config ".general.focus_events" "true")
    true_color=$(get_config ".general.true_color" "true")
    terminal=$(get_config ".general.default_terminal" "tmux-256color")

    cat << EOF
# -----------------------------------------------------------------------------
# General Settings
# -----------------------------------------------------------------------------

# Prefix key
set -g prefix ${prefix}
bind ${prefix#*-} send-prefix
EOF

    if [[ -n "$prefix2" ]]; then
        echo "set -g prefix2 ${prefix2}"
    fi

    cat << EOF

# Base index (start counting from $base_index)
set -g base-index ${base_index}
setw -g pane-base-index ${base_index}

# Mouse support
set -g mouse $([ "$mouse" = "true" ] && echo "on" || echo "off")

# History
set -g history-limit ${history}

# Reduce escape time (faster vim response)
set -sg escape-time ${escape_time}

# Focus events (for vim autoread)
set -g focus-events $([ "$focus" = "true" ] && echo "on" || echo "off")

# True color support
EOF

    if [[ "$true_color" == "true" ]]; then
        cat << EOF
set -g default-terminal "${terminal}"
set -ga terminal-overrides ",*256col*:Tc"
set -ga terminal-overrides ",xterm-256color:Tc"
EOF
    else
        echo "set -g default-terminal \"${terminal}\""
    fi

    echo ""
}

## Generate window settings
_generate_window_settings() {
    local renumber auto_rename

    renumber=$(get_config ".windows.renumber" "true")
    auto_rename=$(get_config ".windows.auto_rename" "true")

    cat << EOF
# -----------------------------------------------------------------------------
# Window Settings
# -----------------------------------------------------------------------------

# Automatically renumber windows
set -g renumber-windows $([ "$renumber" = "true" ] && echo "on" || echo "off")

# Automatic window renaming
setw -g automatic-rename $([ "$auto_rename" = "true" ] && echo "on" || echo "off")

EOF
}

## Generate pane settings
_generate_pane_settings() {
    local retain_path display_time

    retain_path=$(get_config ".panes.retain_path" "true")
    display_time=$(get_config ".panes.display_time" "2000")

    cat << EOF
# -----------------------------------------------------------------------------
# Pane Settings
# -----------------------------------------------------------------------------

# Pane display time
set -g display-panes-time ${display_time}

EOF

    if [[ "$retain_path" == "true" ]]; then
        cat << 'EOF'
# New panes retain current path
bind '"' split-window -v -c "#{pane_current_path}"
bind % split-window -h -c "#{pane_current_path}"

EOF
    fi
}

## Generate keybindings
_generate_keybindings() {
    local reload split_h split_v zoom close
    local vim_mode

    reload=$(get_config ".keybindings.reload" "r")
    split_h=$(get_config ".keybindings.split_horizontal" "|")
    split_v=$(get_config ".keybindings.split_vertical" "-")
    zoom=$(get_config ".keybindings.zoom_pane" "z")
    close=$(get_config ".keybindings.close_pane" "x")
    vim_mode=$(get_config ".modules.navigation.vim_mode" "true")

    cat << EOF
# -----------------------------------------------------------------------------
# Keybindings
# -----------------------------------------------------------------------------

# Reload configuration
bind ${reload} source-file "${GENERATED_CONF_FILE}" \\; display-message "Config reloaded!"

# Split panes (with current path)
bind "${split_h}" split-window -h -c "#{pane_current_path}"
bind "${split_v}" split-window -v -c "#{pane_current_path}"

# Zoom pane
bind ${zoom} resize-pane -Z

# Close pane
bind ${close} kill-pane

EOF

    # Vim-style navigation
    if [[ "$vim_mode" == "true" ]]; then
        local copy_cmd
        copy_cmd=$(get_copy_command)

        cat << 'EOF'
# Vim-style pane navigation
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# Vim-style pane resizing
bind -r H resize-pane -L 5
bind -r J resize-pane -D 5
bind -r K resize-pane -U 5
bind -r L resize-pane -R 5

# Copy mode vi keys
setw -g mode-keys vi
bind -T copy-mode-vi v send-keys -X begin-selection
EOF

        # Use copy-pipe-and-cancel if copy_command is configured
        if [[ -n "$copy_cmd" ]]; then
            echo "bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel \"${copy_cmd}\""
        else
            echo "bind -T copy-mode-vi y send-keys -X copy-selection-and-cancel"
        fi

        cat << 'EOF'
bind -T copy-mode-vi Escape send-keys -X cancel

EOF
    fi

    # Conditional keybindings (if available)
    if check_command generate_conditional_keybindings; then
        local conditional_bindings
        conditional_bindings=$(generate_conditional_keybindings "${PIMPMYTMUX_CONFIG_FILE:-}" 2>/dev/null || true)
        if [[ -n "$conditional_bindings" ]]; then
            echo ""
            echo "$conditional_bindings"
        fi
    fi
}

## Generate status bar configuration
_generate_status_bar() {
    local position interval left right left_len right_len

    position=$(get_config ".status_bar.position" "bottom")
    interval=$(get_config ".status_bar.interval" "5")
    left=$(get_config ".status_bar.left" " #S | #I:#W ")
    right=$(get_config ".status_bar.right" " %H:%M %d-%b ")
    left_len=$(get_config ".status_bar.left_length" "40")
    right_len=$(get_config ".status_bar.right_length" "80")

    cat << EOF
# -----------------------------------------------------------------------------
# Status Bar
# -----------------------------------------------------------------------------

# Status bar position
set -g status-position ${position}

# Update interval
set -g status-interval ${interval}

# Status bar length
set -g status-left-length ${left_len}
set -g status-right-length ${right_len}

EOF
}

## Main function to generate complete tmux.conf
generate_tmux_conf() {
    local config_file="${1:-$DEFAULT_CONFIG_FILE}"
    local output_file="${2:-$GENERATED_CONF_FILE}"
    local dry_run="${3:-false}"

    export PIMPMYTMUX_CONFIG_FILE="$config_file"

    log_info "Generating tmux configuration..."
    log_verbose "Config file: $config_file"
    log_verbose "Output file: $output_file"

    # Validate config first
    if ! validate_config "$config_file"; then
        log_error "Configuration validation failed"
        return 1
    fi

    # Generate config to temp file first
    local temp_file
    temp_file=$(mktemp)

    {
        _generate_preamble
        _generate_general_settings
        _generate_window_settings
        _generate_pane_settings
        _generate_keybindings

        # Generate navigation configuration if enabled
        if config_enabled ".modules.navigation.enabled"; then
            if config_enabled ".modules.navigation.vim_mode"; then
                local nav_copy_cmd
                nav_copy_cmd=$(get_copy_command)
                generate_vim_mode_config "$nav_copy_cmd" 2>/dev/null || true
            fi
            if config_enabled ".modules.navigation.fzf_integration"; then
                generate_fzf_bindings 2>/dev/null || true
            fi
            if config_enabled ".modules.navigation.smart_splits"; then
                generate_smart_splits_config 2>/dev/null || true
            fi
        fi

        # Generate monitoring configuration if enabled
        if config_enabled ".modules.monitoring.enabled"; then
            generate_status_bar_config 2>/dev/null || _generate_status_bar
        else
            _generate_status_bar
        fi

        # Generate theme configuration
        local theme
        theme=$(get_config ".theme" "cyberpunk")
        if [[ -n "$theme" ]]; then
            generate_theme_config "$theme" || log_warn "Could not load theme: $theme"
        fi

    } > "$temp_file"

    if [[ "$dry_run" == "true" ]]; then
        log_info "Dry run - generated config:"
        cat "$temp_file"
        rm -f "$temp_file"
        return 0
    fi

    # Ensure output directory exists
    ensure_dir "$(dirname "$output_file")"

    # Move temp file to output
    mv "$temp_file" "$output_file"

    log_success "Generated: $output_file"
    return 0
}

## Create symlink from ~/.tmux.conf to our generated config
setup_tmux_conf_symlink() {
    local target="$HOME/.tmux.conf"
    local source="${GENERATED_CONF_FILE}"

    symlink_safe "$source" "$target"
    log_success "Created symlink: ~/.tmux.conf -> $source"
}
