#!/usr/bin/env bash
# pimpmytmux - Git status for status bar
# Shows git branch and status in tmux status bar

# Guard against re-sourcing
[[ -n "${_PIMPMYTMUX_GIT_STATUS_LOADED:-}" ]] && return 0
_PIMPMYTMUX_GIT_STATUS_LOADED=1

# -----------------------------------------------------------------------------
# Cache configuration
# -----------------------------------------------------------------------------

PIMPMYTMUX_GIT_CACHE_FILE="${PIMPMYTMUX_CACHE_DIR:-$HOME/.cache/pimpmytmux}/git_status"
PIMPMYTMUX_GIT_CACHE_TTL="${PIMPMYTMUX_GIT_CACHE_TTL:-5}"  # seconds

# -----------------------------------------------------------------------------
# Icons (Nerd Font)
# -----------------------------------------------------------------------------

GIT_ICON_BRANCH="${GIT_ICON_BRANCH:-}"
GIT_ICON_DIRTY="${GIT_ICON_DIRTY:-*}"
GIT_ICON_STAGED="${GIT_ICON_STAGED:-+}"
GIT_ICON_AHEAD="${GIT_ICON_AHEAD:-↑}"
GIT_ICON_BEHIND="${GIT_ICON_BEHIND:-↓}"
GIT_ICON_DIVERGED="${GIT_ICON_DIVERGED:-⇕}"
GIT_ICON_STASH="${GIT_ICON_STASH:-$}"
GIT_ICON_CLEAN="${GIT_ICON_CLEAN:-✓}"

# Fallback icons for non-nerd-font terminals
if [[ "${PIMPMYTMUX_NERD_FONT:-true}" != "true" ]]; then
    GIT_ICON_BRANCH="git:"
fi

# -----------------------------------------------------------------------------
# Git information functions
# -----------------------------------------------------------------------------

## Check if we're in a git repository
_is_git_repo() {
    git rev-parse --is-inside-work-tree &>/dev/null
}

## Get current branch name
_git_branch() {
    git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null
}

## Check if there are uncommitted changes
_git_is_dirty() {
    [[ -n "$(git status --porcelain 2>/dev/null)" ]]
}

## Get number of staged files
_git_staged_count() {
    git diff --cached --numstat 2>/dev/null | wc -l | tr -d ' '
}

## Get number of modified files
_git_modified_count() {
    git diff --numstat 2>/dev/null | wc -l | tr -d ' '
}

## Get number of untracked files
_git_untracked_count() {
    git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' '
}

## Get ahead/behind count from upstream
_git_ahead_behind() {
    local upstream
    upstream=$(git rev-parse --abbrev-ref @{upstream} 2>/dev/null)

    if [[ -z "$upstream" ]]; then
        echo ""
        return
    fi

    local ahead behind
    ahead=$(git rev-list --count @{upstream}..HEAD 2>/dev/null)
    behind=$(git rev-list --count HEAD..@{upstream} 2>/dev/null)

    local result=""
    [[ "$ahead" -gt 0 ]] && result+="${GIT_ICON_AHEAD}${ahead}"
    [[ "$behind" -gt 0 ]] && result+="${GIT_ICON_BEHIND}${behind}"

    echo "$result"
}

## Get stash count
_git_stash_count() {
    git stash list 2>/dev/null | wc -l | tr -d ' '
}

# -----------------------------------------------------------------------------
# Status formatting
# -----------------------------------------------------------------------------

## Format git status for display
format_git_status() {
    local cwd="${1:-$(pwd)}"

    # Change to the directory
    cd "$cwd" 2>/dev/null || return

    # Check if it's a git repo
    if ! _is_git_repo; then
        echo ""
        return
    fi

    local branch status_icons=""

    # Get branch
    branch=$(_git_branch)
    [[ -z "$branch" ]] && return

    # Check dirty state
    if _git_is_dirty; then
        local staged modified untracked

        staged=$(_git_staged_count)
        modified=$(_git_modified_count)
        untracked=$(_git_untracked_count)

        [[ "$staged" -gt 0 ]] && status_icons+="${GIT_ICON_STAGED}${staged}"
        [[ "$modified" -gt 0 ]] && status_icons+="${GIT_ICON_DIRTY}${modified}"
    fi

    # Ahead/behind
    local ahead_behind
    ahead_behind=$(_git_ahead_behind)
    [[ -n "$ahead_behind" ]] && status_icons+=" $ahead_behind"

    # Stash
    local stash_count
    stash_count=$(_git_stash_count)
    [[ "$stash_count" -gt 0 ]] && status_icons+=" ${GIT_ICON_STASH}${stash_count}"

    # Format output
    if [[ -n "$status_icons" ]]; then
        echo "${GIT_ICON_BRANCH}${branch} ${status_icons}"
    else
        echo "${GIT_ICON_BRANCH}${branch}"
    fi
}

# -----------------------------------------------------------------------------
# Cached git status for performance
# -----------------------------------------------------------------------------

## Get git status with caching
get_git_status() {
    local pane_path="${1:-$(tmux display-message -p '#{pane_current_path}')}"
    local cache_dir
    cache_dir=$(dirname "$PIMPMYTMUX_GIT_CACHE_FILE")

    mkdir -p "$cache_dir"

    # Check cache
    local cache_key cache_file
    cache_key=$(echo "$pane_path" | md5sum | cut -d' ' -f1)
    cache_file="${cache_dir}/git_${cache_key}"

    if [[ -f "$cache_file" ]]; then
        local cache_age
        cache_age=$(($(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null)))

        if [[ "$cache_age" -lt "$PIMPMYTMUX_GIT_CACHE_TTL" ]]; then
            cat "$cache_file"
            return
        fi
    fi

    # Generate fresh status
    local status
    status=$(format_git_status "$pane_path")

    # Update cache
    echo "$status" > "$cache_file"
    echo "$status"
}

## Clear git status cache
clear_git_cache() {
    rm -f "${PIMPMYTMUX_CACHE_DIR:-$HOME/.cache/pimpmytmux}"/git_* 2>/dev/null
}

# -----------------------------------------------------------------------------
# Status bar integration
# -----------------------------------------------------------------------------

## Generate git status tmux format string
## Usage in status-right: #(pimpmytmux git-status)
git_status_tmux() {
    get_git_status
}

# If called directly, output git status
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    git_status_tmux
fi
