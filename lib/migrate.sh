#!/usr/bin/env bash
# pimpmytmux - Configuration migration
# https://github.com/christopherlouet/pimpmytmux

# Guard against re-sourcing
[[ -n "${_PIMPMYTMUX_MIGRATE_LOADED:-}" ]] && return 0
_PIMPMYTMUX_MIGRATE_LOADED=1

# shellcheck source=lib/core.sh
source "${PIMPMYTMUX_LIB_DIR:-$(dirname "${BASH_SOURCE[0]}")}/core.sh"

# -----------------------------------------------------------------------------
# Version Detection
# -----------------------------------------------------------------------------

## Detect current config version
## Usage: detect_config_version
detect_config_version() {
    local config_file="${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml"

    if [[ ! -f "$config_file" ]]; then
        echo "unknown"
        return 0
    fi

    local version=""

    if check_command yq; then
        local yq_type
        yq_type=$(detect_yq_version 2>/dev/null || echo "go")

        if [[ "$yq_type" == "go" ]]; then
            version=$(yq eval '.version // ""' "$config_file" 2>/dev/null | tr -d '"')
        fi
    fi

    if [[ -z "$version" ]]; then
        # Check for version field with grep
        version=$(grep -E '^version:' "$config_file" 2>/dev/null | head -1 | cut -d: -f2- | tr -d ' "')
    fi

    if [[ -z "$version" ]]; then
        # Old format without version - assume 0.1.0
        echo "0.1.0"
        return 0
    fi

    echo "$version"
}

## Compare two version strings
## Usage: compare_versions <version1> <version2>
## Returns: -1 if v1 < v2, 0 if equal, 1 if v1 > v2
compare_versions() {
    local v1="$1"
    local v2="$2"

    # Split versions into components
    IFS='.' read -ra v1_parts <<< "$v1"
    IFS='.' read -ra v2_parts <<< "$v2"

    # Compare each component
    for i in 0 1 2; do
        local p1="${v1_parts[$i]:-0}"
        local p2="${v2_parts[$i]:-0}"

        if [[ "$p1" -lt "$p2" ]]; then
            echo "-1"
            return 0
        elif [[ "$p1" -gt "$p2" ]]; then
            echo "1"
            return 0
        fi
    done

    echo "0"
}

## Check if migration is needed
## Usage: needs_migration
needs_migration() {
    local current_version
    current_version=$(detect_config_version)

    if [[ "$current_version" == "unknown" ]]; then
        return 1
    fi

    local cmp
    cmp=$(compare_versions "$current_version" "$PIMPMYTMUX_VERSION")

    [[ "$cmp" == "-1" ]]
}

# -----------------------------------------------------------------------------
# Migration Steps
# -----------------------------------------------------------------------------

## Get list of migration steps needed
## Usage: get_migration_steps <from_version> <to_version>
get_migration_steps() {
    local from="$1"
    local to="$2"
    local steps=()

    # Compare from version with each migration checkpoint
    local cmp

    # 0.1.0 -> 0.2.0: No structural changes

    # 0.x.x -> 1.0.0: Add version field
    cmp=$(compare_versions "$from" "1.0.0")
    if [[ "$cmp" == "-1" ]]; then
        steps+=("add_version_field")
    fi

    # Output steps
    for step in "${steps[@]}"; do
        echo "$step"
    done
}

## Migration: Add version field to config
## Usage: migrate_add_version_field <config_file>
migrate_add_version_field() {
    local config_file="$1"

    # Check if version already exists
    if grep -q '^version:' "$config_file" 2>/dev/null; then
        log_debug "Version field already exists"
        return 0
    fi

    log_info "Adding version field to config..."

    # Add version at the beginning of file
    local temp_file
    temp_file=$(mktemp)

    echo "version: \"$PIMPMYTMUX_VERSION\"" > "$temp_file"
    cat "$config_file" >> "$temp_file"
    mv "$temp_file" "$config_file"

    log_debug "Added version: $PIMPMYTMUX_VERSION"
}

# -----------------------------------------------------------------------------
# Backup & Rollback
# -----------------------------------------------------------------------------

## Create backup before migration
## Usage: backup_before_migrate
backup_before_migrate() {
    local config_file="${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml"
    local backup_dir="${PIMPMYTMUX_DATA_DIR}/backups/migration"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="${backup_dir}/pimpmytmux_${timestamp}.yaml"

    ensure_dir "$backup_dir"

    if [[ -f "$config_file" ]]; then
        cp "$config_file" "$backup_file"
        log_debug "Created migration backup: $backup_file"
        echo "$backup_file"
    fi
}

## Rollback migration from backup
## Usage: rollback_migration <backup_path>
rollback_migration() {
    local backup_path="$1"
    local config_file="${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml"

    if [[ ! -f "$backup_path" ]]; then
        log_error "Backup not found: $backup_path"
        return 1
    fi

    cp "$backup_path" "$config_file"
    log_success "Configuration restored from backup"
}

# -----------------------------------------------------------------------------
# Main Migration
# -----------------------------------------------------------------------------

## Run migration
## Usage: migrate_config
migrate_config() {
    local current_version
    current_version=$(detect_config_version)

    if [[ "$current_version" == "unknown" ]]; then
        log_info "No configuration found, nothing to migrate"
        return 0
    fi

    local cmp
    cmp=$(compare_versions "$current_version" "$PIMPMYTMUX_VERSION")

    if [[ "$cmp" == "0" ]]; then
        log_info "Configuration is already at version $PIMPMYTMUX_VERSION"
        return 0
    fi

    if [[ "$cmp" == "1" ]]; then
        log_warn "Configuration version ($current_version) is newer than pimpmytmux ($PIMPMYTMUX_VERSION)"
        return 0
    fi

    log_info "Migrating configuration from $current_version to $PIMPMYTMUX_VERSION..."

    # Create backup
    local backup_path
    backup_path=$(backup_before_migrate)

    # Get and execute migration steps
    local steps
    steps=$(get_migration_steps "$current_version" "$PIMPMYTMUX_VERSION")

    while IFS= read -r step; do
        if [[ -n "$step" ]]; then
            log_verbose "Running migration step: $step"

            case "$step" in
                add_version_field)
                    migrate_add_version_field "${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml"
                    ;;
                *)
                    log_warn "Unknown migration step: $step"
                    ;;
            esac
        fi
    done <<< "$steps"

    log_success "Migration complete!"
    log_info "Backup saved at: $backup_path"
}

## Show migration status
## Usage: migration_status
migration_status() {
    local current_version
    current_version=$(detect_config_version)

    echo ""
    echo -e "${BOLD}Migration Status${RESET}"
    echo "────────────────────────────────────"
    echo "Current config version: $current_version"
    echo "pimpmytmux version:     $PIMPMYTMUX_VERSION"

    if needs_migration; then
        echo -e "Status: ${YELLOW}Migration available${RESET}"
        echo ""
        echo "Run 'pimpmytmux migrate' to upgrade your configuration."
    else
        echo -e "Status: ${GREEN}Up to date${RESET}"
    fi
    echo ""
}
