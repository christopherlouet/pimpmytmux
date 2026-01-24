#!/usr/bin/env bash
# pimpmytmux - Plugin system
# https://github.com/christopherlouet/pimpmytmux

# Guard against re-sourcing
[[ -n "${_PIMPMYTMUX_PLUGINS_LOADED:-}" ]] && return 0
_PIMPMYTMUX_PLUGINS_LOADED=1

# shellcheck source=lib/core.sh
source "${PIMPMYTMUX_LIB_DIR:-$(dirname "${BASH_SOURCE[0]}")}/core.sh"

# -----------------------------------------------------------------------------
# Constants
# -----------------------------------------------------------------------------

PIMPMYTMUX_PLUGINS_DIR="${PIMPMYTMUX_PLUGINS_DIR:-${PIMPMYTMUX_DATA_DIR}/plugins}"
PIMPMYTMUX_PLUGINS_ENABLED_FILE="${PIMPMYTMUX_CONFIG_DIR}/plugins.enabled"

# -----------------------------------------------------------------------------
# Plugin Directory Management
# -----------------------------------------------------------------------------

## Get plugins directory path
## Usage: get_plugins_dir
get_plugins_dir() {
    echo "$PIMPMYTMUX_PLUGINS_DIR"
}

## Initialize plugins directory
## Usage: init_plugins_dir
init_plugins_dir() {
    ensure_dir "$PIMPMYTMUX_PLUGINS_DIR"
    log_debug "Initialized plugins directory: $PIMPMYTMUX_PLUGINS_DIR"
}

# -----------------------------------------------------------------------------
# Plugin Listing
# -----------------------------------------------------------------------------

## List all installed plugins
## Usage: list_plugins
list_plugins() {
    local plugins_dir="$PIMPMYTMUX_PLUGINS_DIR"

    if [[ ! -d "$plugins_dir" ]]; then
        return 0
    fi

    for plugin_dir in "$plugins_dir"/*/; do
        if [[ -d "$plugin_dir" ]] && [[ -f "$plugin_dir/plugin.yaml" ]]; then
            local name
            name=$(basename "$plugin_dir")
            echo "$name"
        fi
    done
}

## List enabled plugins
## Usage: list_enabled_plugins
list_enabled_plugins() {
    if [[ ! -f "$PIMPMYTMUX_PLUGINS_ENABLED_FILE" ]]; then
        return 0
    fi

    while IFS= read -r plugin; do
        if [[ -n "$plugin" ]] && is_plugin_installed "$plugin"; then
            echo "$plugin"
        fi
    done < "$PIMPMYTMUX_PLUGINS_ENABLED_FILE"
}

# -----------------------------------------------------------------------------
# Plugin Info
# -----------------------------------------------------------------------------

## Get plugin info field
## Usage: get_plugin_info <plugin_name> <field>
get_plugin_info() {
    local name="$1"
    local field="$2"
    local plugin_dir="$PIMPMYTMUX_PLUGINS_DIR/$name"
    local plugin_yaml="$plugin_dir/plugin.yaml"

    if [[ ! -f "$plugin_yaml" ]]; then
        return 1
    fi

    if check_command yq; then
        local yq_type
        yq_type=$(detect_yq_version 2>/dev/null || echo "go")

        if [[ "$yq_type" == "go" ]]; then
            yq eval ".$field // \"\"" "$plugin_yaml" 2>/dev/null | grep -v '^$' || return 1
        fi
    else
        grep "^${field}:" "$plugin_yaml" 2>/dev/null | cut -d: -f2- | sed 's/^ *//' | tr -d '"'
    fi
}

## Check if plugin is installed
## Usage: is_plugin_installed <plugin_name>
is_plugin_installed() {
    local name="$1"
    local plugin_dir="$PIMPMYTMUX_PLUGINS_DIR/$name"

    [[ -d "$plugin_dir" ]] && [[ -f "$plugin_dir/plugin.yaml" ]]
}

## Check if plugin is enabled
## Usage: is_plugin_enabled <plugin_name>
is_plugin_enabled() {
    local name="$1"

    if [[ ! -f "$PIMPMYTMUX_PLUGINS_ENABLED_FILE" ]]; then
        return 1
    fi

    grep -q "^${name}$" "$PIMPMYTMUX_PLUGINS_ENABLED_FILE" 2>/dev/null
}

# -----------------------------------------------------------------------------
# Plugin Validation
# -----------------------------------------------------------------------------

## Validate plugin structure
## Usage: validate_plugin_structure <plugin_dir>
validate_plugin_structure() {
    local plugin_dir="$1"
    local plugin_yaml="$plugin_dir/plugin.yaml"

    # Check plugin.yaml exists
    if [[ ! -f "$plugin_yaml" ]]; then
        log_error "Missing plugin.yaml in $plugin_dir"
        return 1
    fi

    # Check required fields
    local name
    name=$(get_plugin_info "$(basename "$plugin_dir")" "name")

    if [[ -z "$name" ]]; then
        log_error "Plugin missing required 'name' field"
        return 1
    fi

    return 0
}

# -----------------------------------------------------------------------------
# Plugin Installation
# -----------------------------------------------------------------------------

## Extract plugin name from URL
## Usage: extract_plugin_name_from_url <url>
extract_plugin_name_from_url() {
    local url="$1"

    # Remove trailing .git
    url="${url%.git}"

    # Get last part of path
    local name
    name=$(basename "$url")

    echo "$name"
}

## Install plugin from URL
## Usage: install_plugin <url> [--skip-clone]
install_plugin() {
    local url="$1"
    local skip_clone="${2:-}"

    if [[ -z "$url" ]]; then
        log_error "URL required"
        return 1
    fi

    local name
    name=$(extract_plugin_name_from_url "$url")

    # Check if already installed
    if is_plugin_installed "$name"; then
        log_error "Plugin '$name' already installed"
        return 1
    fi

    local plugin_dir="$PIMPMYTMUX_PLUGINS_DIR/$name"

    # Skip actual clone for testing
    if [[ "$skip_clone" != "--skip-clone" ]]; then
        log_info "Installing plugin: $name"

        # Clone repository
        if ! git clone --quiet "$url" "$plugin_dir" 2>/dev/null; then
            log_error "Failed to clone plugin repository"
            return 1
        fi

        # Validate structure
        if ! validate_plugin_structure "$plugin_dir"; then
            rm -rf "$plugin_dir"
            log_error "Invalid plugin structure"
            return 1
        fi

        # Run on_install hook
        run_plugin_hook "$name" "on_install"

        # Enable by default
        enable_plugin "$name"

        log_success "Plugin '$name' installed"
    fi

    return 0
}

## Remove installed plugin
## Usage: remove_plugin <plugin_name>
remove_plugin() {
    local name="$1"

    if ! is_plugin_installed "$name"; then
        log_error "Plugin '$name' not installed"
        return 1
    fi

    local plugin_dir="$PIMPMYTMUX_PLUGINS_DIR/$name"

    # Run on_remove hook if exists
    run_plugin_hook "$name" "on_remove"

    # Disable plugin
    disable_plugin "$name"

    # Remove directory
    rm -rf "$plugin_dir"

    log_success "Plugin '$name' removed"
}

## Update all installed plugins
## Usage: update_plugins
update_plugins() {
    local plugins_dir="$PIMPMYTMUX_PLUGINS_DIR"
    local updated=0

    for plugin_dir in "$plugins_dir"/*/; do
        if [[ -d "$plugin_dir/.git" ]]; then
            local name
            name=$(basename "$plugin_dir")

            log_info "Updating $name..."

            cd "$plugin_dir" || continue

            if git pull --quiet 2>/dev/null; then
                log_success "Updated: $name"
                ((updated++))
            else
                log_warn "Failed to update: $name"
            fi

            cd - > /dev/null || true
        fi
    done

    if [[ $updated -eq 0 ]]; then
        log_info "No plugins to update"
    else
        log_success "Updated $updated plugin(s)"
    fi
}

# -----------------------------------------------------------------------------
# Plugin Enable/Disable
# -----------------------------------------------------------------------------

## Enable a plugin
## Usage: enable_plugin <plugin_name>
enable_plugin() {
    local name="$1"

    if ! is_plugin_installed "$name"; then
        log_error "Plugin '$name' not installed"
        return 1
    fi

    # Create enabled file if needed
    ensure_dir "$(dirname "$PIMPMYTMUX_PLUGINS_ENABLED_FILE")"

    # Add to enabled list if not already there
    if ! is_plugin_enabled "$name"; then
        echo "$name" >> "$PIMPMYTMUX_PLUGINS_ENABLED_FILE"
    fi

    log_debug "Enabled plugin: $name"
}

## Disable a plugin
## Usage: disable_plugin <plugin_name>
disable_plugin() {
    local name="$1"

    if [[ ! -f "$PIMPMYTMUX_PLUGINS_ENABLED_FILE" ]]; then
        return 0
    fi

    # Remove from enabled list
    local temp_file
    temp_file=$(mktemp)

    grep -v "^${name}$" "$PIMPMYTMUX_PLUGINS_ENABLED_FILE" > "$temp_file" 2>/dev/null || true
    mv "$temp_file" "$PIMPMYTMUX_PLUGINS_ENABLED_FILE"

    log_debug "Disabled plugin: $name"
}

# -----------------------------------------------------------------------------
# Plugin Hooks
# -----------------------------------------------------------------------------

## Run a plugin hook
## Usage: run_plugin_hook <plugin_name> <hook_name>
## Hooks: on_install, on_remove, on_apply, on_reload
run_plugin_hook() {
    local name="$1"
    local hook="$2"
    local plugin_dir="$PIMPMYTMUX_PLUGINS_DIR/$name"
    local hook_script="$plugin_dir/${hook}.sh"

    if [[ ! -x "$hook_script" ]]; then
        log_debug "No $hook hook for plugin $name"
        return 0
    fi

    log_debug "Running $hook hook for $name"

    # Execute hook in subshell with plugin context
    (
        export PIMPMYTMUX_PLUGIN_DIR="$plugin_dir"
        export PIMPMYTMUX_PLUGIN_NAME="$name"
        cd "$plugin_dir" || exit 1
        "$hook_script"
    )
}

## Run hooks for all enabled plugins
## Usage: run_all_plugin_hooks <hook_name>
run_all_plugin_hooks() {
    local hook="$1"

    while IFS= read -r plugin; do
        if [[ -n "$plugin" ]]; then
            run_plugin_hook "$plugin" "$hook"
        fi
    done < <(list_enabled_plugins)
}

# -----------------------------------------------------------------------------
# Plugin Config Integration
# -----------------------------------------------------------------------------

## Load plugin configurations
## Usage: load_plugin_configs
load_plugin_configs() {
    while IFS= read -r plugin; do
        if [[ -n "$plugin" ]]; then
            local plugin_dir="$PIMPMYTMUX_PLUGINS_DIR/$plugin"
            local config_file="$plugin_dir/config.sh"

            if [[ -f "$config_file" ]]; then
                log_debug "Loading config for plugin: $plugin"
                # shellcheck source=/dev/null
                source "$config_file"
            fi
        fi
    done < <(list_enabled_plugins)
}

## Generate plugin tmux configurations
## Usage: generate_plugin_configs
generate_plugin_configs() {
    local has_output=false

    while IFS= read -r plugin; do
        if [[ -n "$plugin" ]]; then
            local plugin_dir="$PIMPMYTMUX_PLUGINS_DIR/$plugin"
            local tmux_conf="$plugin_dir/tmux.conf"

            if [[ -f "$tmux_conf" ]]; then
                if [[ "$has_output" != "true" ]]; then
                    echo ""
                    echo "# -----------------------------------------------------------------------------"
                    echo "# Plugin Configurations"
                    echo "# -----------------------------------------------------------------------------"
                    has_output=true
                fi

                echo ""
                echo "# Plugin: $plugin"
                cat "$tmux_conf"
            fi
        fi
    done < <(list_enabled_plugins)
}
