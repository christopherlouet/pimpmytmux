#!/usr/bin/env bash
# pimpmytmux - Memory monitoring
# Display memory usage in status bar

# Guard against re-sourcing
[[ -n "${_PIMPMYTMUX_MEMORY_LOADED:-}" ]] && return 0
_PIMPMYTMUX_MEMORY_LOADED=1

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

MEMORY_ICON="${MEMORY_ICON:-}"
MEMORY_ICON_FALLBACK="RAM:"

# Thresholds for color coding
MEMORY_THRESHOLD_HIGH="${MEMORY_THRESHOLD_HIGH:-80}"
MEMORY_THRESHOLD_MEDIUM="${MEMORY_THRESHOLD_MEDIUM:-60}"

# -----------------------------------------------------------------------------
# Platform-specific memory functions
# -----------------------------------------------------------------------------

## Get memory usage on Linux
_memory_linux() {
    local mem_info total available used_percent

    mem_info=$(</proc/meminfo)

    total=$(echo "$mem_info" | awk '/MemTotal/ {print $2}')
    available=$(echo "$mem_info" | awk '/MemAvailable/ {print $2}')

    if [[ -z "$available" ]]; then
        # Fallback for older kernels
        local free buffers cached
        free=$(echo "$mem_info" | awk '/MemFree/ {print $2}')
        buffers=$(echo "$mem_info" | awk '/Buffers/ {print $2}')
        cached=$(echo "$mem_info" | awk '/^Cached/ {print $2}')
        available=$((free + buffers + cached))
    fi

    local used=$((total - available))
    used_percent=$((used * 100 / total))

    echo "$used_percent"
}

## Get memory info in human readable format (Linux)
_memory_linux_human() {
    local mem_info total available

    mem_info=$(</proc/meminfo)

    total=$(echo "$mem_info" | awk '/MemTotal/ {printf "%.1f", $2/1048576}')
    available=$(echo "$mem_info" | awk '/MemAvailable/ {printf "%.1f", $2/1048576}')

    local used
    used=$(awk "BEGIN {printf \"%.1f\", $total - $available}")

    echo "${used}/${total}G"
}

## Get memory usage on macOS
_memory_macos() {
    local page_size pages_free pages_active pages_inactive pages_speculative pages_wired
    local total_pages used_pages used_percent

    page_size=$(pagesize)

    # Parse vm_stat output
    local vm_stat_out
    vm_stat_out=$(vm_stat)

    pages_free=$(echo "$vm_stat_out" | awk '/Pages free/ {gsub(/\./, "", $3); print $3}')
    pages_active=$(echo "$vm_stat_out" | awk '/Pages active/ {gsub(/\./, "", $3); print $3}')
    pages_inactive=$(echo "$vm_stat_out" | awk '/Pages inactive/ {gsub(/\./, "", $3); print $3}')
    pages_speculative=$(echo "$vm_stat_out" | awk '/Pages speculative/ {gsub(/\./, "", $3); print $3}')
    pages_wired=$(echo "$vm_stat_out" | awk '/Pages wired/ {gsub(/\./, "", $4); print $4}')

    # Get total memory from sysctl
    local total_bytes
    total_bytes=$(sysctl -n hw.memsize 2>/dev/null)
    total_pages=$((total_bytes / page_size))

    # Calculate used (active + wired)
    used_pages=$((pages_active + pages_wired))
    used_percent=$((used_pages * 100 / total_pages))

    echo "$used_percent"
}

## Get memory info in human readable format (macOS)
_memory_macos_human() {
    local total_bytes used_bytes

    total_bytes=$(sysctl -n hw.memsize 2>/dev/null)
    local total_gb
    total_gb=$(awk "BEGIN {printf \"%.1f\", $total_bytes / 1073741824}")

    local usage_percent
    usage_percent=$(_memory_macos)
    local used_gb
    used_gb=$(awk "BEGIN {printf \"%.1f\", $total_gb * $usage_percent / 100}")

    echo "${used_gb}/${total_gb}G"
}

## Get memory usage (cross-platform)
get_memory_usage() {
    case "$(uname -s)" in
        Linux*)
            _memory_linux
            ;;
        Darwin*)
            _memory_macos
            ;;
        *)
            echo "0"
            ;;
    esac
}

## Get memory usage in human format (cross-platform)
get_memory_human() {
    case "$(uname -s)" in
        Linux*)
            _memory_linux_human
            ;;
        Darwin*)
            _memory_macos_human
            ;;
        *)
            echo "N/A"
            ;;
    esac
}

# -----------------------------------------------------------------------------
# Formatting
# -----------------------------------------------------------------------------

## Format memory with bar
format_memory_bar() {
    local usage="${1:-0}"
    local width="${2:-5}"
    local filled=$(( usage * width / 100 ))
    local empty=$(( width - filled ))

    local bar=""
    for ((i=0; i<filled; i++)); do bar+="▰"; done
    for ((i=0; i<empty; i++)); do bar+="▱"; done

    echo "$bar"
}

## Get formatted memory status for tmux
get_memory_status() {
    local format="${1:-percent}"  # percent, human, bar, both
    local usage
    usage=$(get_memory_usage)

    local icon="$MEMORY_ICON"
    [[ -z "$icon" ]] && icon="$MEMORY_ICON_FALLBACK"

    case "$format" in
        human)
            echo "${icon}$(get_memory_human)"
            ;;
        bar)
            echo "${icon}$(format_memory_bar "$usage")"
            ;;
        both)
            echo "${icon}${usage}% $(format_memory_bar "$usage" 3)"
            ;;
        percent|*)
            echo "${icon}${usage}%"
            ;;
    esac
}

# If called directly, output memory status
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    get_memory_status "${1:-percent}"
fi
