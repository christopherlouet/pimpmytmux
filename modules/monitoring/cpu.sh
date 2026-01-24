#!/usr/bin/env bash
# pimpmytmux - CPU monitoring
# Display CPU usage in status bar

# Guard against re-sourcing
[[ -n "${_PIMPMYTMUX_CPU_LOADED:-}" ]] && return 0
_PIMPMYTMUX_CPU_LOADED=1

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

CPU_ICON="${CPU_ICON:-}"
CPU_ICON_FALLBACK="CPU:"

# Thresholds for color coding
CPU_THRESHOLD_HIGH="${CPU_THRESHOLD_HIGH:-80}"
CPU_THRESHOLD_MEDIUM="${CPU_THRESHOLD_MEDIUM:-50}"

# -----------------------------------------------------------------------------
# Platform-specific CPU functions
# -----------------------------------------------------------------------------

## Get CPU usage on Linux
_cpu_linux() {
    # Read from /proc/stat
    local cpu_line prev_line
    local prev_idle prev_total idle total

    # First reading
    prev_line=$(head -1 /proc/stat)
    prev_idle=$(echo "$prev_line" | awk '{print $5}')
    prev_total=$(echo "$prev_line" | awk '{sum=0; for(i=2;i<=NF;i++) sum+=$i; print sum}')

    # Wait briefly
    sleep 0.1

    # Second reading
    cpu_line=$(head -1 /proc/stat)
    idle=$(echo "$cpu_line" | awk '{print $5}')
    total=$(echo "$cpu_line" | awk '{sum=0; for(i=2;i<=NF;i++) sum+=$i; print sum}')

    # Calculate usage
    local diff_idle=$((idle - prev_idle))
    local diff_total=$((total - prev_total))

    if [[ $diff_total -gt 0 ]]; then
        echo $(( (1000 * (diff_total - diff_idle) / diff_total + 5) / 10 ))
    else
        echo "0"
    fi
}

## Get CPU usage on macOS
_cpu_macos() {
    # Use top for quick CPU reading
    local cpu_usage
    cpu_usage=$(top -l 1 -n 0 2>/dev/null | grep "CPU usage" | awk '{print $3}' | tr -d '%')

    if [[ -n "$cpu_usage" ]]; then
        printf "%.0f" "$cpu_usage"
    else
        echo "0"
    fi
}

## Get CPU usage (cross-platform)
get_cpu_usage() {
    case "$(uname -s)" in
        Linux*)
            _cpu_linux
            ;;
        Darwin*)
            _cpu_macos
            ;;
        *)
            echo "0"
            ;;
    esac
}

# -----------------------------------------------------------------------------
# Formatting
# -----------------------------------------------------------------------------

## Format CPU with bar
format_cpu_bar() {
    local usage="${1:-0}"
    local width="${2:-5}"
    local filled=$(( usage * width / 100 ))
    local empty=$(( width - filled ))

    local bar=""
    for ((i=0; i<filled; i++)); do bar+="▰"; done
    for ((i=0; i<empty; i++)); do bar+="▱"; done

    echo "$bar"
}

## Format CPU with color indicators
format_cpu_color() {
    local usage="${1:-0}"

    # Return tmux format string with color
    if [[ "$usage" -ge "$CPU_THRESHOLD_HIGH" ]]; then
        echo "#[fg=red]${usage}%#[default]"
    elif [[ "$usage" -ge "$CPU_THRESHOLD_MEDIUM" ]]; then
        echo "#[fg=yellow]${usage}%#[default]"
    else
        echo "#[fg=green]${usage}%#[default]"
    fi
}

## Get formatted CPU status for tmux
get_cpu_status() {
    local format="${1:-percent}"  # percent, bar, both
    local usage
    usage=$(get_cpu_usage)

    local icon="$CPU_ICON"
    [[ -z "$icon" ]] && icon="$CPU_ICON_FALLBACK"

    case "$format" in
        bar)
            echo "${icon}$(format_cpu_bar "$usage")"
            ;;
        both)
            echo "${icon}${usage}% $(format_cpu_bar "$usage" 3)"
            ;;
        color)
            echo "${icon}$(format_cpu_color "$usage")"
            ;;
        percent|*)
            echo "${icon}${usage}%"
            ;;
    esac
}

# If called directly, output CPU status
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    get_cpu_status "${1:-percent}"
fi
