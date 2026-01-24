#!/usr/bin/env bash
# pimpmytmux - Weather widget
# Display weather info in status bar using wttr.in

# Guard against re-sourcing
[[ -n "${_PIMPMYTMUX_WEATHER_LOADED:-}" ]] && return 0
_PIMPMYTMUX_WEATHER_LOADED=1

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

WEATHER_LOCATION="${WEATHER_LOCATION:-}"  # Empty = auto-detect
WEATHER_FORMAT="${WEATHER_FORMAT:-3}"     # wttr.in format (1-4)
WEATHER_CACHE_TTL="${WEATHER_CACHE_TTL:-900}"  # 15 minutes
WEATHER_CACHE_FILE="${PIMPMYTMUX_CACHE_DIR:-$HOME/.cache/pimpmytmux}/weather"

WEATHER_ICON="${WEATHER_ICON:-}"  # Weather icon prefix

# -----------------------------------------------------------------------------
# Weather functions
# -----------------------------------------------------------------------------

## Get weather from wttr.in
_fetch_weather() {
    local location="${WEATHER_LOCATION:-}"
    local format="${WEATHER_FORMAT:-3}"
    local url="https://wttr.in/${location}?format=${format}"

    # Timeout after 2 seconds
    curl -sf -m 2 "$url" 2>/dev/null
}

## Get cached weather or fetch new
get_weather() {
    local cache_file="$WEATHER_CACHE_FILE"
    local cache_dir
    cache_dir=$(dirname "$cache_file")

    mkdir -p "$cache_dir"

    # Check cache
    if [[ -f "$cache_file" ]]; then
        local cache_age
        cache_age=$(($(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null)))

        if [[ "$cache_age" -lt "$WEATHER_CACHE_TTL" ]]; then
            cat "$cache_file"
            return
        fi
    fi

    # Fetch fresh weather
    local weather
    weather=$(_fetch_weather)

    if [[ -n "$weather" ]]; then
        echo "$weather" > "$cache_file"
        echo "$weather"
    elif [[ -f "$cache_file" ]]; then
        # Return stale cache if fetch fails
        cat "$cache_file"
    else
        echo ""
    fi
}

## Get formatted weather status for tmux
get_weather_status() {
    local weather
    weather=$(get_weather)

    if [[ -z "$weather" ]]; then
        echo ""
        return
    fi

    # Remove any newlines/extra spaces
    weather=$(echo "$weather" | tr '\n' ' ' | sed 's/  */ /g' | sed 's/^ *//;s/ *$//')

    if [[ -n "$WEATHER_ICON" ]]; then
        echo "${WEATHER_ICON}${weather}"
    else
        echo "$weather"
    fi
}

## Clear weather cache
clear_weather_cache() {
    rm -f "$WEATHER_CACHE_FILE"
}

## Set weather location
set_weather_location() {
    local location="$1"
    export WEATHER_LOCATION="$location"
    clear_weather_cache
    get_weather_status
}

# If called directly, output weather status
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    get_weather_status
fi
