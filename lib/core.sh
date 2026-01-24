#!/usr/bin/env bash
# pimpmytmux - Core utility functions
# https://github.com/christopherlouet/pimpmytmux

# Guard against re-sourcing
[[ -n "${_PIMPMYTMUX_CORE_LOADED:-}" ]] && return 0
_PIMPMYTMUX_CORE_LOADED=1

set -euo pipefail

# -----------------------------------------------------------------------------
# Constants
# -----------------------------------------------------------------------------

PIMPMYTMUX_VERSION="${PIMPMYTMUX_VERSION:-0.2.0}"
PIMPMYTMUX_CONFIG_DIR="${PIMPMYTMUX_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/pimpmytmux}"
PIMPMYTMUX_DATA_DIR="${PIMPMYTMUX_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/pimpmytmux}"
PIMPMYTMUX_CACHE_DIR="${PIMPMYTMUX_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/pimpmytmux}"

# Colors for output (respect NO_COLOR)
if [[ -z "${NO_COLOR:-}" && -t 2 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    MAGENTA='\033[0;35m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    DIM='\033[2m'
    RESET='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' MAGENTA='' CYAN='' BOLD='' DIM='' RESET=''
fi

# Verbosity level (0=quiet, 1=normal, 2=verbose, 3=debug)
PIMPMYTMUX_VERBOSITY="${PIMPMYTMUX_VERBOSITY:-1}"

# -----------------------------------------------------------------------------
# Logging functions
# -----------------------------------------------------------------------------

## Log an info message (shown at verbosity >= 1)
log_info() {
    [[ "${PIMPMYTMUX_VERBOSITY}" -ge 1 ]] && echo -e "${GREEN}[INFO]${RESET} $*" >&2
    return 0
}

## Log a success message
log_success() {
    [[ "${PIMPMYTMUX_VERBOSITY}" -ge 1 ]] && echo -e "${GREEN}[OK]${RESET} $*" >&2
    return 0
}

## Log a warning message (shown at verbosity >= 1)
log_warn() {
    [[ "${PIMPMYTMUX_VERBOSITY}" -ge 1 ]] && echo -e "${YELLOW}[WARN]${RESET} $*" >&2
    return 0
}

## Log an error message (always shown)
log_error() {
    echo -e "${RED}[ERROR]${RESET} $*" >&2
    return 0
}

## Log a debug message (shown at verbosity >= 3)
log_debug() {
    [[ "${PIMPMYTMUX_VERBOSITY}" -ge 3 ]] && echo -e "${DIM}[DEBUG]${RESET} $*" >&2
    return 0
}

## Log a verbose message (shown at verbosity >= 2)
log_verbose() {
    [[ "${PIMPMYTMUX_VERBOSITY}" -ge 2 ]] && echo -e "${CYAN}[VERBOSE]${RESET} $*" >&2
    return 0
}

# -----------------------------------------------------------------------------
# Platform detection
# -----------------------------------------------------------------------------

## Detect the current platform
## Returns: linux, macos, wsl, or unknown
get_platform() {
    local uname_out
    uname_out="$(uname -s)"

    case "${uname_out}" in
        Linux*)
            # Check if running in WSL
            if grep -qEi "(microsoft|wsl)" /proc/version 2>/dev/null; then
                echo "wsl"
            else
                echo "linux"
            fi
            ;;
        Darwin*)
            echo "macos"
            ;;
        CYGWIN*|MINGW*|MSYS*)
            echo "windows"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

## Check if running on macOS
is_macos() {
    [[ "$(get_platform)" == "macos" ]]
}

## Check if running on Linux
is_linux() {
    [[ "$(get_platform)" == "linux" ]]
}

## Check if running in WSL
is_wsl() {
    [[ "$(get_platform)" == "wsl" ]]
}

# -----------------------------------------------------------------------------
# Dependency checking
# -----------------------------------------------------------------------------

## Check if a command exists
## Usage: check_command <command>
## Returns: 0 if exists, 1 if not
check_command() {
    command -v "$1" &>/dev/null
}

## Require a command to exist, exit with error if not found
## Usage: require_command <command> [package_hint]
require_command() {
    local cmd="$1"
    local hint="${2:-}"

    if ! check_command "$cmd"; then
        log_error "Required command '$cmd' not found."
        if [[ -n "$hint" ]]; then
            log_error "Install with: $hint"
        fi
        exit 1
    fi
    log_debug "Found required command: $cmd"
}

## Check if a dependency exists (soft check, returns status)
## Usage: check_dependency <command>
check_dependency() {
    local cmd="$1"
    if check_command "$cmd"; then
        log_debug "Dependency found: $cmd"
        return 0
    else
        log_debug "Dependency missing: $cmd"
        return 1
    fi
}

## Get tmux version as a comparable number (e.g., 3.2 -> 320)
get_tmux_version() {
    local version
    version=$(tmux -V 2>/dev/null | sed 's/[^0-9.]//g')
    if [[ -z "$version" ]]; then
        echo "0"
        return 1
    fi
    # Convert to comparable number (3.2 -> 320, 3.2a -> 320)
    echo "$version" | awk -F. '{printf "%d%02d", $1, $2}'
}

## Check if tmux version is at least the specified version
## Usage: check_tmux_version <min_version> (e.g., 3.2)
check_tmux_version() {
    local min_version="$1"
    local min_num current_num
    min_num=$(echo "$min_version" | awk -F. '{printf "%d%02d", $1, $2}')
    current_num=$(get_tmux_version)

    [[ "$current_num" -ge "$min_num" ]]
}

# -----------------------------------------------------------------------------
# File operations
# -----------------------------------------------------------------------------

## Create a backup of a file with timestamp
## Usage: backup_file <file_path>
## Returns: path to backup file
backup_file() {
    local file="$1"
    local backup_dir="${PIMPMYTMUX_DATA_DIR}/backups"
    local timestamp backup_path

    if [[ ! -f "$file" ]]; then
        log_debug "No file to backup: $file"
        return 0
    fi

    mkdir -p "$backup_dir"
    timestamp=$(date +%Y%m%d_%H%M%S)
    backup_path="${backup_dir}/$(basename "$file").${timestamp}.bak"

    cp "$file" "$backup_path"
    log_verbose "Backed up $file to $backup_path"
    echo "$backup_path"
}

## Create a symlink safely (with backup of existing file)
## Usage: symlink_safe <source> <target>
symlink_safe() {
    local source="$1"
    local target="$2"

    # If target exists and is not a symlink, back it up
    if [[ -e "$target" && ! -L "$target" ]]; then
        log_info "Backing up existing file: $target"
        backup_file "$target"
        rm -f "$target"
    elif [[ -L "$target" ]]; then
        # Remove existing symlink
        rm -f "$target"
    fi

    # Create parent directory if needed
    mkdir -p "$(dirname "$target")"

    # Create symlink
    ln -sf "$source" "$target"
    log_verbose "Created symlink: $target -> $source"
}

## Ensure a directory exists
## Usage: ensure_dir <path>
ensure_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        log_debug "Created directory: $dir"
    fi
}

# -----------------------------------------------------------------------------
# String utilities
# -----------------------------------------------------------------------------

## Trim whitespace from a string
## Usage: trim <string>
trim() {
    local var="$*"
    # Remove leading whitespace
    var="${var#"${var%%[![:space:]]*}"}"
    # Remove trailing whitespace
    var="${var%"${var##*[![:space:]]}"}"
    echo -n "$var"
}

## Check if a string is empty or contains only whitespace
## Usage: is_empty <string>
is_empty() {
    local trimmed
    trimmed=$(trim "$1")
    [[ -z "$trimmed" ]]
}

## Convert string to lowercase
## Usage: to_lower <string>
to_lower() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

## Convert string to uppercase
## Usage: to_upper <string>
to_upper() {
    echo "$1" | tr '[:lower:]' '[:upper:]'
}

# -----------------------------------------------------------------------------
# Array utilities
# -----------------------------------------------------------------------------

## Check if an array contains a value
## Usage: array_contains <value> <array_elements...>
array_contains() {
    local needle="$1"
    shift
    local element
    for element in "$@"; do
        [[ "$element" == "$needle" ]] && return 0
    done
    return 1
}

# -----------------------------------------------------------------------------
# tmux helpers
# -----------------------------------------------------------------------------

## Check if we're inside a tmux session
is_inside_tmux() {
    [[ -n "${TMUX:-}" ]]
}

## Get the tmux config file path
get_tmux_conf_path() {
    echo "${PIMPMYTMUX_CONFIG_DIR}/tmux.conf"
}

## Reload tmux configuration
reload_tmux() {
    local conf_path
    conf_path=$(get_tmux_conf_path)

    if ! is_inside_tmux; then
        log_warn "Not inside tmux, cannot reload"
        return 1
    fi

    if [[ ! -f "$conf_path" ]]; then
        log_error "Config file not found: $conf_path"
        return 1
    fi

    tmux source-file "$conf_path"
    log_success "Reloaded tmux configuration"
}

# -----------------------------------------------------------------------------
# Initialization
# -----------------------------------------------------------------------------

## Initialize pimpmytmux directories
init_directories() {
    ensure_dir "$PIMPMYTMUX_CONFIG_DIR"
    ensure_dir "$PIMPMYTMUX_DATA_DIR"
    ensure_dir "$PIMPMYTMUX_CACHE_DIR"
    ensure_dir "${PIMPMYTMUX_DATA_DIR}/sessions"
    ensure_dir "${PIMPMYTMUX_DATA_DIR}/backups"
    log_debug "Initialized pimpmytmux directories"
}
