#!/usr/bin/env bash
# pimpmytmux - Battery monitoring
# Display battery status in status bar

# Guard against re-sourcing
[[ -n "${_PIMPMYTMUX_BATTERY_LOADED:-}" ]] && return 0
_PIMPMYTMUX_BATTERY_LOADED=1

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

BATTERY_ICON_CHARGING="${BATTERY_ICON_CHARGING:-}"
BATTERY_ICON_DISCHARGING="${BATTERY_ICON_DISCHARGING:-}"
BATTERY_ICON_FULL="${BATTERY_ICON_FULL:-}"
BATTERY_ICON_HIGH="${BATTERY_ICON_HIGH:-}"
BATTERY_ICON_MEDIUM="${BATTERY_ICON_MEDIUM:-}"
BATTERY_ICON_LOW="${BATTERY_ICON_LOW:-}"
BATTERY_ICON_CRITICAL="${BATTERY_ICON_CRITICAL:-}"

# Fallback icons
BATTERY_ICON_CHARGING_FALLBACK="+"
BATTERY_ICON_DISCHARGING_FALLBACK="-"

# Thresholds
BATTERY_THRESHOLD_HIGH="${BATTERY_THRESHOLD_HIGH:-80}"
BATTERY_THRESHOLD_MEDIUM="${BATTERY_THRESHOLD_MEDIUM:-40}"
BATTERY_THRESHOLD_LOW="${BATTERY_THRESHOLD_LOW:-20}"

# -----------------------------------------------------------------------------
# Platform-specific battery functions
# -----------------------------------------------------------------------------

## Get battery info on Linux
_battery_linux() {
    local bat_path="/sys/class/power_supply"
    local battery=""

    # Find battery (BAT0, BAT1, or similar)
    for bat in "$bat_path"/BAT*; do
        if [[ -d "$bat" ]]; then
            battery="$bat"
            break
        fi
    done

    # Also check for CMB* (some Thinkpads)
    if [[ -z "$battery" ]]; then
        for bat in "$bat_path"/CMB*; do
            if [[ -d "$bat" ]]; then
                battery="$bat"
                break
            fi
        done
    fi

    if [[ -z "$battery" ]]; then
        echo ""
        return 1
    fi

    local capacity status
    capacity=$(cat "$battery/capacity" 2>/dev/null)
    status=$(cat "$battery/status" 2>/dev/null)

    # Output format: percentage|status
    echo "${capacity}|${status}"
}

## Get battery info on macOS
_battery_macos() {
    local pmset_out
    pmset_out=$(pmset -g batt 2>/dev/null)

    if [[ -z "$pmset_out" ]]; then
        echo ""
        return 1
    fi

    local capacity status
    capacity=$(echo "$pmset_out" | grep -o '[0-9]*%' | tr -d '%')
    status=$(echo "$pmset_out" | grep -o 'charging\|discharging\|charged\|AC attached' | head -1)

    case "$status" in
        charging|"AC attached")
            status="Charging"
            ;;
        discharging)
            status="Discharging"
            ;;
        charged|full)
            status="Full"
            ;;
    esac

    echo "${capacity}|${status}"
}

## Get battery info (cross-platform)
get_battery_info() {
    case "$(uname -s)" in
        Linux*)
            _battery_linux
            ;;
        Darwin*)
            _battery_macos
            ;;
        *)
            echo ""
            ;;
    esac
}

# -----------------------------------------------------------------------------
# Formatting
# -----------------------------------------------------------------------------

## Get battery icon based on level and status
get_battery_icon() {
    local level="${1:-0}"
    local status="${2:-Discharging}"

    if [[ "$status" == "Charging" ]]; then
        echo "$BATTERY_ICON_CHARGING"
        return
    fi

    if [[ "$status" == "Full" ]]; then
        echo "$BATTERY_ICON_FULL"
        return
    fi

    if [[ "$level" -ge "$BATTERY_THRESHOLD_HIGH" ]]; then
        echo "$BATTERY_ICON_HIGH"
    elif [[ "$level" -ge "$BATTERY_THRESHOLD_MEDIUM" ]]; then
        echo "$BATTERY_ICON_MEDIUM"
    elif [[ "$level" -ge "$BATTERY_THRESHOLD_LOW" ]]; then
        echo "$BATTERY_ICON_LOW"
    else
        echo "$BATTERY_ICON_CRITICAL"
    fi
}

## Format battery with horizontal bar
format_battery_hbar() {
    local level="${1:-0}"

    # Use block characters for horizontal bar
    local chars=("▏" "▎" "▍" "▌" "▋" "▊" "▉" "█")
    local index=$(( level * 8 / 100 ))
    [[ $index -gt 7 ]] && index=7

    echo "${chars[$index]}"
}

## Get formatted battery status for tmux
get_battery_status() {
    local format="${1:-icon}"  # icon, percent, both, bar

    local info level status
    info=$(get_battery_info)

    if [[ -z "$info" ]]; then
        # No battery (desktop)
        echo ""
        return
    fi

    level="${info%%|*}"
    status="${info##*|}"

    local icon
    icon=$(get_battery_icon "$level" "$status")

    case "$format" in
        icon)
            echo "$icon"
            ;;
        percent)
            echo "${level}%"
            ;;
        bar)
            echo "$(format_battery_hbar "$level")"
            ;;
        both|*)
            echo "${icon}${level}%"
            ;;
    esac
}

## Check if on battery power
is_on_battery() {
    local info status
    info=$(get_battery_info)

    if [[ -z "$info" ]]; then
        return 1  # No battery = not on battery
    fi

    status="${info##*|}"
    [[ "$status" == "Discharging" ]]
}

## Check if battery is low
is_battery_low() {
    local info level
    info=$(get_battery_info)

    if [[ -z "$info" ]]; then
        return 1
    fi

    level="${info%%|*}"
    [[ "$level" -lt "$BATTERY_THRESHOLD_LOW" ]]
}

# If called directly, output battery status
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    get_battery_status "${1:-both}"
fi
