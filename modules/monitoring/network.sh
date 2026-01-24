#!/usr/bin/env bash
# pimpmytmux - Network monitoring
# Display network info in status bar

# Guard against re-sourcing
[[ -n "${_PIMPMYTMUX_NETWORK_LOADED:-}" ]] && return 0
_PIMPMYTMUX_NETWORK_LOADED=1

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

NETWORK_ICON="${NETWORK_ICON:-󰖩}"
NETWORK_ICON_WIFI="${NETWORK_ICON_WIFI:-}"
NETWORK_ICON_ETHERNET="${NETWORK_ICON_ETHERNET:-󰈀}"
NETWORK_ICON_DISCONNECTED="${NETWORK_ICON_DISCONNECTED:-󰖪}"
NETWORK_ICON_VPN="${NETWORK_ICON_VPN:-󰖂}"

# Fallback icons
NETWORK_ICON_FALLBACK="NET:"

# -----------------------------------------------------------------------------
# Network detection functions
# -----------------------------------------------------------------------------

## Get active network interface on Linux
_get_active_interface_linux() {
    # Try to find interface with default route
    local iface
    iface=$(ip route get 8.8.8.8 2>/dev/null | awk '{print $5; exit}')

    if [[ -n "$iface" ]]; then
        echo "$iface"
        return
    fi

    # Fallback: find first interface that's up (excluding lo)
    iface=$(ip link show up 2>/dev/null | grep -v "lo:" | grep -oP '^\d+: \K[^:@]+' | head -1)
    echo "$iface"
}

## Get active network interface on macOS
_get_active_interface_macos() {
    # Get interface for default route
    local iface
    iface=$(route get default 2>/dev/null | awk '/interface:/ {print $2}')
    echo "$iface"
}

## Get IP address on Linux
_get_ip_linux() {
    local iface="${1:-}"

    if [[ -z "$iface" ]]; then
        iface=$(_get_active_interface_linux)
    fi

    if [[ -z "$iface" ]]; then
        echo ""
        return
    fi

    ip addr show "$iface" 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 | head -1
}

## Get IP address on macOS
_get_ip_macos() {
    local iface="${1:-}"

    if [[ -z "$iface" ]]; then
        iface=$(_get_active_interface_macos)
    fi

    if [[ -z "$iface" ]]; then
        echo ""
        return
    fi

    ifconfig "$iface" 2>/dev/null | awk '/inet / {print $2}' | head -1
}

## Get local IP address
get_local_ip() {
    case "$(uname -s)" in
        Linux*)
            _get_ip_linux "$@"
            ;;
        Darwin*)
            _get_ip_macos "$@"
            ;;
        *)
            echo ""
            ;;
    esac
}

## Get active network interface
get_active_interface() {
    case "$(uname -s)" in
        Linux*)
            _get_active_interface_linux
            ;;
        Darwin*)
            _get_active_interface_macos
            ;;
        *)
            echo ""
            ;;
    esac
}

## Detect connection type (wifi, ethernet, vpn)
get_connection_type() {
    local iface
    iface=$(get_active_interface)

    if [[ -z "$iface" ]]; then
        echo "disconnected"
        return
    fi

    # Check for VPN interfaces
    if [[ "$iface" =~ ^(tun|tap|wg|vpn|ppp) ]]; then
        echo "vpn"
        return
    fi

    # Check for wireless on Linux
    if [[ -d "/sys/class/net/$iface/wireless" ]]; then
        echo "wifi"
        return
    fi

    # Check for wireless on macOS
    if [[ "$(uname -s)" == "Darwin" ]]; then
        if networksetup -listallhardwareports 2>/dev/null | grep -A1 "Wi-Fi" | grep -q "$iface"; then
            echo "wifi"
            return
        fi
    fi

    # Default to ethernet
    echo "ethernet"
}

## Get WiFi SSID on Linux
_get_ssid_linux() {
    local iface
    iface=$(get_active_interface)

    if [[ -n "$iface" ]]; then
        iwgetid -r "$iface" 2>/dev/null || nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes:' | cut -d: -f2
    fi
}

## Get WiFi SSID on macOS
_get_ssid_macos() {
    /System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I 2>/dev/null \
        | awk '/ SSID/ {print substr($0, index($0, $2))}'
}

## Get current SSID
get_ssid() {
    case "$(uname -s)" in
        Linux*)
            _get_ssid_linux
            ;;
        Darwin*)
            _get_ssid_macos
            ;;
        *)
            echo ""
            ;;
    esac
}

# -----------------------------------------------------------------------------
# Formatting
# -----------------------------------------------------------------------------

## Get network icon based on connection type
get_network_icon() {
    local conn_type
    conn_type=$(get_connection_type)

    case "$conn_type" in
        wifi)
            echo "$NETWORK_ICON_WIFI"
            ;;
        vpn)
            echo "$NETWORK_ICON_VPN"
            ;;
        ethernet)
            echo "$NETWORK_ICON_ETHERNET"
            ;;
        disconnected|*)
            echo "$NETWORK_ICON_DISCONNECTED"
            ;;
    esac
}

## Get formatted network status for tmux
get_network_status() {
    local format="${1:-ip}"  # ip, ssid, type, full

    local icon ip conn_type ssid
    icon=$(get_network_icon)
    ip=$(get_local_ip)
    conn_type=$(get_connection_type)

    if [[ "$conn_type" == "disconnected" ]]; then
        echo "${icon}offline"
        return
    fi

    case "$format" in
        ip)
            echo "${icon}${ip}"
            ;;
        ssid)
            if [[ "$conn_type" == "wifi" ]]; then
                ssid=$(get_ssid)
                echo "${icon}${ssid:-$ip}"
            else
                echo "${icon}${conn_type}"
            fi
            ;;
        type)
            echo "${icon}${conn_type}"
            ;;
        full|*)
            if [[ "$conn_type" == "wifi" ]]; then
                ssid=$(get_ssid)
                echo "${icon}${ssid:-wifi} ${ip}"
            else
                echo "${icon}${ip}"
            fi
            ;;
    esac
}

## Check if connected to network
is_connected() {
    local ip
    ip=$(get_local_ip)
    [[ -n "$ip" ]]
}

# If called directly, output network status
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    get_network_status "${1:-ip}"
fi
