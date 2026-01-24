#!/usr/bin/env bash
# pimpmytmux - Backup and restore functions
# https://github.com/christopherlouet/pimpmytmux

# Guard against re-sourcing
[[ -n "${_PIMPMYTMUX_BACKUP_LOADED:-}" ]] && return 0
_PIMPMYTMUX_BACKUP_LOADED=1

# -----------------------------------------------------------------------------
# Dependencies
# -----------------------------------------------------------------------------

# Ensure core is loaded
if [[ -z "${_PIMPMYTMUX_CORE_LOADED:-}" ]]; then
    # shellcheck source=./core.sh
    source "${PIMPMYTMUX_LIB_DIR:-$(dirname "${BASH_SOURCE[0]}")}/core.sh"
fi

# -----------------------------------------------------------------------------
# Constants
# -----------------------------------------------------------------------------

# Default number of backups to keep
readonly PIMPMYTMUX_BACKUP_KEEP="${PIMPMYTMUX_BACKUP_KEEP:-10}"

# Backup directory
PIMPMYTMUX_BACKUP_DIR="${PIMPMYTMUX_DATA_DIR}/backups"

# -----------------------------------------------------------------------------
# Backup Functions
# -----------------------------------------------------------------------------

## Create a backup of a configuration file
## Usage: backup_config <file_path>
## Returns: Path to the backup file (empty if no file to backup)
backup_config() {
    local file="$1"

    # Check if file exists
    if [[ ! -f "$file" ]]; then
        log_debug "backup_config: No file to backup: $file"
        echo ""
        return 0
    fi

    # Ensure backup directory exists
    mkdir -p "$PIMPMYTMUX_BACKUP_DIR"

    # Generate backup filename with timestamp
    local basename
    basename=$(basename "$file")
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_path="${PIMPMYTMUX_BACKUP_DIR}/${basename}.${timestamp}.bak"

    # Copy file to backup location
    if cp "$file" "$backup_path"; then
        log_verbose "Created backup: $backup_path"
        echo "$backup_path"
        return 0
    else
        log_error "Failed to create backup of $file"
        return 1
    fi
}

## Restore a configuration file from backup
## Usage: restore_backup <backup_path> <target_path>
## Returns: 0 on success, 1 on failure
restore_backup() {
    local backup_path="$1"
    local target_path="$2"

    # Check backup exists
    if [[ ! -f "$backup_path" ]]; then
        log_error "Backup file not found: $backup_path"
        return 1
    fi

    # Create target directory if needed
    local target_dir
    target_dir=$(dirname "$target_path")
    if [[ ! -d "$target_dir" ]]; then
        mkdir -p "$target_dir"
        log_debug "Created directory: $target_dir"
    fi

    # Copy backup to target
    if cp "$backup_path" "$target_path"; then
        log_success "Restored $target_path from backup"
        return 0
    else
        log_error "Failed to restore from backup: $backup_path"
        return 1
    fi
}

## List available backups
## Usage: list_backups [filter]
## filter: Optional filename filter (e.g., "tmux.conf")
list_backups() {
    local filter="${1:-}"

    # Ensure backup directory exists
    if [[ ! -d "$PIMPMYTMUX_BACKUP_DIR" ]]; then
        log_debug "No backup directory found"
        return 0
    fi

    # List backups
    local backups
    if [[ -n "$filter" ]]; then
        backups=$(ls -1t "$PIMPMYTMUX_BACKUP_DIR"/*"$filter"*.bak 2>/dev/null || true)
    else
        backups=$(ls -1t "$PIMPMYTMUX_BACKUP_DIR"/*.bak 2>/dev/null || true)
    fi

    if [[ -z "$backups" ]]; then
        log_info "No backups found"
        return 0
    fi

    echo "$backups"
    return 0
}

## Clean up old backups, keeping only the most recent N
## Usage: cleanup_old_backups [keep_count]
## keep_count: Number of backups to keep (default: $PIMPMYTMUX_BACKUP_KEEP)
cleanup_old_backups() {
    local keep_count="${1:-$PIMPMYTMUX_BACKUP_KEEP}"

    # Ensure backup directory exists
    if [[ ! -d "$PIMPMYTMUX_BACKUP_DIR" ]]; then
        log_debug "No backup directory to clean"
        return 0
    fi

    # Get all backup files sorted by modification time (newest first)
    local backup_files
    mapfile -t backup_files < <(ls -1t "$PIMPMYTMUX_BACKUP_DIR"/*.bak 2>/dev/null || true)

    local total=${#backup_files[@]}
    if [[ $total -le $keep_count ]]; then
        log_debug "Backup count ($total) <= keep count ($keep_count), nothing to clean"
        return 0
    fi

    # Remove old backups
    local removed=0
    for ((i = keep_count; i < total; i++)); do
        local file="${backup_files[$i]}"
        if [[ -f "$file" ]]; then
            rm -f "$file"
            log_debug "Removed old backup: $file"
            ((removed++))
        fi
    done

    log_verbose "Cleaned up $removed old backups"
    return 0
}

## Get the most recent backup for a file
## Usage: get_latest_backup <filename>
## filename: Base filename to search for (e.g., "tmux.conf")
## Returns: Path to the most recent backup (empty if none found)
get_latest_backup() {
    local filename="$1"

    if [[ ! -d "$PIMPMYTMUX_BACKUP_DIR" ]]; then
        echo ""
        return 0
    fi

    # Find the most recent backup for this file
    local latest
    latest=$(ls -1t "$PIMPMYTMUX_BACKUP_DIR"/"$filename".*.bak 2>/dev/null | head -1)

    if [[ -n "$latest" && -f "$latest" ]]; then
        echo "$latest"
    else
        echo ""
    fi
    return 0
}

## Backup tmux configuration before applying changes
## Usage: backup_before_apply
## Returns: Path to backup or empty if no existing config
backup_before_apply() {
    local tmux_conf="${HOME}/.tmux.conf"
    local generated_conf
    generated_conf=$(get_tmux_conf_path)

    local backup_path=""

    # Backup ~/.tmux.conf if it exists and is not a symlink
    if [[ -f "$tmux_conf" && ! -L "$tmux_conf" ]]; then
        backup_path=$(backup_config "$tmux_conf")
        if [[ -n "$backup_path" ]]; then
            log_info "Backed up ~/.tmux.conf to $backup_path"
        fi
    fi

    # Also backup generated config if it exists
    if [[ -f "$generated_conf" ]]; then
        local gen_backup
        gen_backup=$(backup_config "$generated_conf")
        if [[ -n "$gen_backup" ]]; then
            log_verbose "Backed up generated config to $gen_backup"
        fi
    fi

    echo "$backup_path"
    return 0
}

## Interactive restore: let user choose from available backups
## Usage: restore_interactive [target_path]
## target_path: Where to restore (default: ~/.tmux.conf)
restore_interactive() {
    local target="${1:-${HOME}/.tmux.conf}"

    # List available backups
    local backups
    mapfile -t backups < <(list_backups "tmux.conf")

    if [[ ${#backups[@]} -eq 0 ]]; then
        log_error "No backups available"
        return 1
    fi

    # If gum is available, use it for selection
    if check_command gum; then
        local selected
        selected=$(printf '%s\n' "${backups[@]}" | gum choose --header "Select backup to restore:")
        if [[ -n "$selected" ]]; then
            restore_backup "$selected" "$target"
            return $?
        fi
    else
        # Simple selection
        echo "Available backups:"
        local i=1
        for backup in "${backups[@]}"; do
            echo "  $i) $(basename "$backup")"
            ((i++))
        done

        echo ""
        read -rp "Select backup number (1-${#backups[@]}): " choice

        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#backups[@]} ]]; then
            local selected="${backups[$((choice-1))]}"
            restore_backup "$selected" "$target"
            return $?
        else
            log_error "Invalid selection"
            return 1
        fi
    fi

    return 1
}
