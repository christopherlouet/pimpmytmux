#!/usr/bin/env bash
# pimpmytmux - Configuration sync via git
# https://github.com/christopherlouet/pimpmytmux

# Guard against re-sourcing
[[ -n "${_PIMPMYTMUX_SYNC_LOADED:-}" ]] && return 0
_PIMPMYTMUX_SYNC_LOADED=1

# shellcheck source=lib/core.sh
source "${PIMPMYTMUX_LIB_DIR:-$(dirname "${BASH_SOURCE[0]}")}/core.sh"

# -----------------------------------------------------------------------------
# Constants
# -----------------------------------------------------------------------------

PIMPMYTMUX_SYNC_DIR="${PIMPMYTMUX_SYNC_DIR:-${PIMPMYTMUX_DATA_DIR}/sync}"
PIMPMYTMUX_SYNC_CONF="${PIMPMYTMUX_CONFIG_DIR}/sync.conf"

# -----------------------------------------------------------------------------
# Sync Configuration
# -----------------------------------------------------------------------------

## Get configured sync repository URL
## Usage: get_sync_repo
get_sync_repo() {
    # Check environment variable first
    if [[ -n "${PIMPMYTMUX_SYNC_REPO:-}" ]]; then
        echo "$PIMPMYTMUX_SYNC_REPO"
        return
    fi

    # Check config file
    if [[ -f "$PIMPMYTMUX_SYNC_CONF" ]]; then
        grep -E '^repo=' "$PIMPMYTMUX_SYNC_CONF" 2>/dev/null | cut -d'=' -f2-
        return
    fi

    echo ""
}

## Set sync repository URL
## Usage: set_sync_repo <url>
set_sync_repo() {
    local url="$1"

    ensure_dir "$(dirname "$PIMPMYTMUX_SYNC_CONF")"

    # Create or update config file
    if [[ -f "$PIMPMYTMUX_SYNC_CONF" ]]; then
        # Update existing
        if grep -q '^repo=' "$PIMPMYTMUX_SYNC_CONF"; then
            sed -i "s|^repo=.*|repo=$url|" "$PIMPMYTMUX_SYNC_CONF"
        else
            echo "repo=$url" >> "$PIMPMYTMUX_SYNC_CONF"
        fi
    else
        cat > "$PIMPMYTMUX_SYNC_CONF" << EOF
# pimpmytmux sync configuration
repo=$url
EOF
    fi

    log_success "Sync repository set to: $url"
}

## Check if sync is configured
## Usage: is_sync_configured
is_sync_configured() {
    local repo
    repo=$(get_sync_repo)
    [[ -n "$repo" ]]
}

# -----------------------------------------------------------------------------
# Sync Directory Management
# -----------------------------------------------------------------------------

## Get sync directory path
## Usage: get_sync_dir
get_sync_dir() {
    echo "$PIMPMYTMUX_SYNC_DIR"
}

## Initialize sync directory
## Usage: init_sync_dir
init_sync_dir() {
    ensure_dir "$PIMPMYTMUX_SYNC_DIR"
    log_debug "Initialized sync directory: $PIMPMYTMUX_SYNC_DIR"
}

## Check if sync directory is a git repo
## Usage: is_sync_repo_initialized
is_sync_repo_initialized() {
    [[ -d "$PIMPMYTMUX_SYNC_DIR/.git" ]]
}

# -----------------------------------------------------------------------------
# File Tracking
# -----------------------------------------------------------------------------

## Get list of files to sync
## Usage: get_sync_files
get_sync_files() {
    local config_dir="$PIMPMYTMUX_CONFIG_DIR"

    # Main config
    if [[ -f "$config_dir/pimpmytmux.yaml" ]]; then
        echo "pimpmytmux.yaml"
    fi

    # Themes
    if [[ -d "$config_dir/themes" ]]; then
        find "$config_dir/themes" -name "*.yaml" -type f 2>/dev/null | while read -r f; do
            echo "themes/$(basename "$f")"
        done
    fi

    # Templates
    if [[ -d "$config_dir/templates" ]]; then
        find "$config_dir/templates" -name "*.yaml" -type f 2>/dev/null | while read -r f; do
            echo "templates/$(basename "$f")"
        done
    fi

    # Session templates
    if [[ -d "$config_dir/session-templates" ]]; then
        find "$config_dir/session-templates" -name "*.yaml" -type f 2>/dev/null | while read -r f; do
            echo "session-templates/$(basename "$f")"
        done
    fi

    # Profiles
    if [[ -d "$config_dir/profiles" ]]; then
        find "$config_dir/profiles" -name "*.yaml" -type f 2>/dev/null | while read -r f; do
            local rel_path="${f#$config_dir/}"
            echo "$rel_path"
        done
    fi
}

## Check if a file should be synced
## Usage: should_sync_file <filename>
should_sync_file() {
    local file="$1"

    # Skip backup files
    [[ "$file" == *.bak ]] && return 1
    [[ "$file" == *.backup ]] && return 1
    [[ "$file" == *~ ]] && return 1

    # Skip git internals
    [[ "$file" == .git/* ]] && return 1

    # Skip temp files
    [[ "$file" == *.tmp ]] && return 1
    [[ "$file" == *.swp ]] && return 1

    # Accept yaml files
    [[ "$file" == *.yaml ]] && return 0
    [[ "$file" == *.yml ]] && return 0

    # Accept conf files
    [[ "$file" == *.conf ]] && return 0

    return 1
}

# -----------------------------------------------------------------------------
# Sync Status
# -----------------------------------------------------------------------------

## Get sync status
## Usage: get_sync_status
get_sync_status() {
    if ! is_sync_repo_initialized; then
        echo "not initialized"
        return
    fi

    cd "$PIMPMYTMUX_SYNC_DIR" || return 1

    if has_local_changes; then
        echo "modified"
    else
        echo "clean"
    fi
}

## Check if there are local changes
## Usage: has_local_changes
has_local_changes() {
    if ! is_sync_repo_initialized; then
        return 1
    fi

    cd "$PIMPMYTMUX_SYNC_DIR" || return 1

    # Check for uncommitted changes
    if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
        return 0
    fi

    return 1
}

## Check if there are remote changes
## Usage: has_remote_changes
has_remote_changes() {
    if ! is_sync_repo_initialized; then
        return 1
    fi

    cd "$PIMPMYTMUX_SYNC_DIR" || return 1

    # Fetch latest
    git fetch --quiet 2>/dev/null || return 1

    # Check if behind
    local behind
    behind=$(git rev-list HEAD..@{u} --count 2>/dev/null || echo "0")

    [[ "$behind" -gt 0 ]]
}

# -----------------------------------------------------------------------------
# Sync Operations
# -----------------------------------------------------------------------------

## Initialize sync with a repository
## Usage: sync_init <repo_url>
sync_init() {
    local repo_url="$1"

    if [[ -z "$repo_url" ]]; then
        log_error "Repository URL required"
        return 1
    fi

    # Save repo configuration
    set_sync_repo "$repo_url"

    # Create sync directory
    init_sync_dir

    # Clone or initialize
    if is_sync_repo_initialized; then
        log_warn "Sync already initialized. Use 'sync pull' to update."
        return 0
    fi

    log_info "Cloning sync repository..."

    if git clone "$repo_url" "$PIMPMYTMUX_SYNC_DIR" 2>/dev/null; then
        log_success "Sync repository cloned"
    else
        # Initialize new repo if clone fails (empty repo)
        cd "$PIMPMYTMUX_SYNC_DIR" || return 1
        git init --quiet
        git remote add origin "$repo_url" 2>/dev/null || true
        log_info "Initialized new sync repository"
    fi
}

## Copy local config to sync directory
## Usage: sync_stage
sync_stage() {
    if ! is_sync_repo_initialized; then
        log_error "Sync not initialized. Run 'pimpmytmux sync init <repo>' first."
        return 1
    fi

    local config_dir="$PIMPMYTMUX_CONFIG_DIR"
    local sync_dir="$PIMPMYTMUX_SYNC_DIR"

    log_info "Staging configuration files..."

    # Copy files to sync directory
    while IFS= read -r file; do
        if [[ -n "$file" ]] && should_sync_file "$file"; then
            local src="$config_dir/$file"
            local dest="$sync_dir/$file"

            if [[ -f "$src" ]]; then
                ensure_dir "$(dirname "$dest")"
                cp "$src" "$dest"
                log_verbose "Staged: $file"
            fi
        fi
    done < <(get_sync_files)

    log_success "Files staged for sync"
}

## Push local changes to remote
## Usage: sync_push [message]
sync_push() {
    local message="${1:-Update pimpmytmux configuration}"

    if ! is_sync_configured; then
        log_error "Sync not configured. Run 'pimpmytmux sync init <repo>' first."
        return 1
    fi

    # Stage files
    sync_stage

    cd "$PIMPMYTMUX_SYNC_DIR" || return 1

    # Check for changes
    if ! has_local_changes; then
        log_info "No changes to push"
        return 0
    fi

    # Commit and push
    git add -A
    git commit -m "$message" --quiet

    log_info "Pushing to remote..."

    if git push origin HEAD 2>/dev/null; then
        log_success "Configuration pushed successfully"
    else
        log_error "Failed to push. Check your repository access."
        return 1
    fi
}

## Pull remote changes
## Usage: sync_pull
sync_pull() {
    if ! is_sync_configured; then
        log_error "Sync not configured. Run 'pimpmytmux sync init <repo>' first."
        return 1
    fi

    if ! is_sync_repo_initialized; then
        log_error "Sync not initialized. Run 'pimpmytmux sync init <repo>' first."
        return 1
    fi

    cd "$PIMPMYTMUX_SYNC_DIR" || return 1

    log_info "Pulling from remote..."

    if git pull --quiet 2>/dev/null; then
        log_success "Configuration pulled successfully"

        # Copy files back to config directory
        sync_apply
    else
        log_error "Failed to pull. Check your repository access."
        return 1
    fi
}

## Apply synced files to config directory
## Usage: sync_apply
sync_apply() {
    local config_dir="$PIMPMYTMUX_CONFIG_DIR"
    local sync_dir="$PIMPMYTMUX_SYNC_DIR"

    log_info "Applying synced configuration..."

    # Copy yaml files from sync to config
    find "$sync_dir" -name "*.yaml" -type f 2>/dev/null | while read -r src; do
        local rel_path="${src#$sync_dir/}"

        if should_sync_file "$rel_path"; then
            local dest="$config_dir/$rel_path"
            ensure_dir "$(dirname "$dest")"
            cp "$src" "$dest"
            log_verbose "Applied: $rel_path"
        fi
    done

    log_success "Configuration applied"
}

## Show sync status
## Usage: sync_status
sync_status() {
    echo ""
    echo -e "${BOLD}Sync Status${RESET}"
    echo "────────────────────────────────────"

    local repo
    repo=$(get_sync_repo)

    if [[ -z "$repo" ]]; then
        echo -e "Repository: ${DIM}not configured${RESET}"
        echo ""
        echo "Configure sync with: pimpmytmux sync init <repo-url>"
        return
    fi

    echo -e "Repository: ${CYAN}$repo${RESET}"

    if is_sync_repo_initialized; then
        local status
        status=$(get_sync_status)

        case "$status" in
            clean)
                echo -e "Status:     ${GREEN}clean${RESET}"
                ;;
            modified)
                echo -e "Status:     ${YELLOW}modified${RESET}"
                ;;
            *)
                echo -e "Status:     ${DIM}$status${RESET}"
                ;;
        esac

        cd "$PIMPMYTMUX_SYNC_DIR" || return

        local last_commit
        last_commit=$(git log -1 --format="%cr" 2>/dev/null || echo "unknown")
        echo -e "Last sync:  ${DIM}$last_commit${RESET}"
    else
        echo -e "Status:     ${YELLOW}not initialized${RESET}"
    fi

    echo ""
}
