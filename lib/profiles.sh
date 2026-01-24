#!/usr/bin/env bash
# pimpmytmux - Profile management
# https://github.com/christopherlouet/pimpmytmux

# Guard against re-sourcing
[[ -n "${_PIMPMYTMUX_PROFILES_LOADED:-}" ]] && return 0
_PIMPMYTMUX_PROFILES_LOADED=1

# shellcheck source=lib/core.sh
source "${PIMPMYTMUX_LIB_DIR:-$(dirname "${BASH_SOURCE[0]}")}/core.sh"

# -----------------------------------------------------------------------------
# Constants
# -----------------------------------------------------------------------------

PIMPMYTMUX_PROFILES_DIR="${PIMPMYTMUX_PROFILES_DIR:-${PIMPMYTMUX_CONFIG_DIR}/profiles}"

# Reserved profile names
readonly RESERVED_PROFILE_NAMES=("current")

# -----------------------------------------------------------------------------
# Profile Directory Functions
# -----------------------------------------------------------------------------

## Get profiles directory path
## Usage: get_profiles_dir
get_profiles_dir() {
    echo "$PIMPMYTMUX_PROFILES_DIR"
}

## Initialize profiles directory structure
## Usage: init_profiles
init_profiles() {
    ensure_dir "$PIMPMYTMUX_PROFILES_DIR"
    ensure_dir "$PIMPMYTMUX_PROFILES_DIR/default"

    # Create default config if not exists
    local default_config="$PIMPMYTMUX_PROFILES_DIR/default/pimpmytmux.yaml"
    if [[ ! -f "$default_config" ]]; then
        create_default_profile_config "$default_config"
    fi

    # Set default as current if no current profile
    if [[ ! -L "$PIMPMYTMUX_PROFILES_DIR/current" ]]; then
        ln -sf "default" "$PIMPMYTMUX_PROFILES_DIR/current"
    fi

    log_debug "Initialized profiles directory: $PIMPMYTMUX_PROFILES_DIR"
}

## Create default profile config file
## Usage: create_default_profile_config <path>
create_default_profile_config() {
    local config_path="$1"

    cat > "$config_path" << 'EOF'
# pimpmytmux profile configuration
# Profile: default

theme: catppuccin

settings:
  prefix: C-a
  base_index: 1
  mouse: true
  vi_mode: true

modules:
  vim_navigation: true
  fzf_integration: true
  dev_tools: true
  system_monitor: true
EOF
}

# -----------------------------------------------------------------------------
# Profile Listing Functions
# -----------------------------------------------------------------------------

## List all available profiles
## Usage: list_profiles
list_profiles() {
    local profiles_dir
    profiles_dir=$(get_profiles_dir)

    if [[ ! -d "$profiles_dir" ]]; then
        return 0
    fi

    local profiles=()
    for dir in "$profiles_dir"/*/; do
        if [[ -d "$dir" ]]; then
            local name
            name=$(basename "$dir")
            # Skip the 'current' symlink
            [[ "$name" == "current" ]] && continue
            profiles+=("$name")
        fi
    done

    # Sort and print
    printf '%s\n' "${profiles[@]}" | sort
}

## Check if a profile exists
## Usage: profile_exists <name>
profile_exists() {
    local name="$1"
    local profile_dir="$PIMPMYTMUX_PROFILES_DIR/$name"

    [[ -d "$profile_dir" ]]
}

# -----------------------------------------------------------------------------
# Current Profile Functions
# -----------------------------------------------------------------------------

## Get the current active profile name
## Usage: get_current_profile
get_current_profile() {
    local current_link="$PIMPMYTMUX_PROFILES_DIR/current"

    if [[ -L "$current_link" ]]; then
        readlink "$current_link"
    else
        # Default to 'default' if no current set
        echo "default"
    fi
}

## Set the current active profile
## Usage: set_current_profile <name>
set_current_profile() {
    local name="$1"

    if ! profile_exists "$name"; then
        log_error "Profile does not exist: $name"
        return 1
    fi

    local current_link="$PIMPMYTMUX_PROFILES_DIR/current"

    # Remove existing symlink
    rm -f "$current_link"

    # Create new symlink
    ln -sf "$name" "$current_link"

    log_debug "Set current profile to: $name"
}

# -----------------------------------------------------------------------------
# Profile Creation Functions
# -----------------------------------------------------------------------------

## Validate profile name
## Usage: is_valid_profile_name <name>
is_valid_profile_name() {
    local name="$1"

    # Must not be empty
    [[ -z "$name" ]] && return 1

    # Must not contain spaces or path separators
    [[ "$name" =~ [[:space:]/\\] ]] && return 1

    # Must not start with . or contain ..
    [[ "$name" =~ ^\.|\.\. ]] && return 1

    # Must not be a reserved name
    for reserved in "${RESERVED_PROFILE_NAMES[@]}"; do
        [[ "$name" == "$reserved" ]] && return 1
    done

    # Must match valid characters (alphanumeric, dash, underscore)
    [[ "$name" =~ ^[a-zA-Z0-9_-]+$ ]]
}

## Create a new profile
## Usage: create_profile <name> [--from <source>]
create_profile() {
    local name="$1"
    shift

    local from_profile=""

    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --from)
                from_profile="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    # Validate name
    if ! is_valid_profile_name "$name"; then
        log_error "Invalid profile name: $name"
        return 1
    fi

    # Check if already exists
    if profile_exists "$name"; then
        log_error "Profile already exists: $name"
        return 1
    fi

    local profile_dir="$PIMPMYTMUX_PROFILES_DIR/$name"
    local config_file="$profile_dir/pimpmytmux.yaml"

    # Create profile directory
    ensure_dir "$profile_dir"

    if [[ -n "$from_profile" ]]; then
        # Copy from source profile
        if ! profile_exists "$from_profile"; then
            log_error "Source profile does not exist: $from_profile"
            rm -rf "$profile_dir"
            return 1
        fi

        local source_config="$PIMPMYTMUX_PROFILES_DIR/$from_profile/pimpmytmux.yaml"
        if [[ -f "$source_config" ]]; then
            cp "$source_config" "$config_file"
            # Update profile name in config
            sed -i "s/^# Profile:.*/# Profile: $name/" "$config_file" 2>/dev/null || true
        else
            create_default_profile_config "$config_file"
        fi
    else
        # Create from template
        create_default_profile_config "$config_file"
        sed -i "s/^# Profile:.*/# Profile: $name/" "$config_file" 2>/dev/null || true
    fi

    log_success "Created profile: $name"
}

# -----------------------------------------------------------------------------
# Profile Deletion Functions
# -----------------------------------------------------------------------------

## Delete a profile
## Usage: delete_profile <name>
delete_profile() {
    local name="$1"

    # Cannot delete default
    if [[ "$name" == "default" ]]; then
        log_error "Cannot delete default profile"
        return 1
    fi

    # Cannot delete current profile
    local current
    current=$(get_current_profile)
    if [[ "$name" == "$current" ]]; then
        log_error "Cannot delete current profile. Switch to another profile first."
        return 1
    fi

    # Check if exists
    if ! profile_exists "$name"; then
        log_error "Profile does not exist: $name"
        return 1
    fi

    local profile_dir="$PIMPMYTMUX_PROFILES_DIR/$name"

    # Remove profile directory
    rm -rf "$profile_dir"

    log_success "Deleted profile: $name"
}

# -----------------------------------------------------------------------------
# Profile Switching Functions
# -----------------------------------------------------------------------------

## Switch to a different profile
## Usage: switch_profile <name>
switch_profile() {
    local name="$1"

    # Check if profile exists
    if ! profile_exists "$name"; then
        log_error "Profile does not exist: $name"
        return 1
    fi

    # Set as current profile
    set_current_profile "$name"

    log_success "Switched to profile: $name"
}

# -----------------------------------------------------------------------------
# Profile Config Path Functions
# -----------------------------------------------------------------------------

## Get config path for a specific profile
## Usage: get_profile_config_path <name>
get_profile_config_path() {
    local name="$1"
    echo "$PIMPMYTMUX_PROFILES_DIR/$name/pimpmytmux.yaml"
}

## Get config path for the active profile
## Usage: get_active_config_path
get_active_config_path() {
    local current
    current=$(get_current_profile)
    get_profile_config_path "$current"
}
