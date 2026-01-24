#!/usr/bin/env bash
# pimpmytmux - Status bar components
# Generates status bar configuration with monitoring widgets

# Guard against re-sourcing
[[ -n "${_PIMPMYTMUX_STATUS_LOADED:-}" ]] && return 0
_PIMPMYTMUX_STATUS_LOADED=1

# shellcheck source=lib/core.sh
source "${PIMPMYTMUX_LIB_DIR:-$(dirname "${BASH_SOURCE[0]}")}/core.sh"

# -----------------------------------------------------------------------------
# Module paths
# -----------------------------------------------------------------------------

PIMPMYTMUX_MODULES_DIR="${PIMPMYTMUX_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/modules"

# -----------------------------------------------------------------------------
# Status bar script generators
# -----------------------------------------------------------------------------

## Generate a script that outputs CPU status
_generate_cpu_script() {
    local script_path="${PIMPMYTMUX_CACHE_DIR}/scripts/cpu.sh"
    local module_path="${PIMPMYTMUX_MODULES_DIR}/monitoring/cpu.sh"

    mkdir -p "$(dirname "$script_path")"

    cat > "$script_path" << EOF
#!/usr/bin/env bash
source "$module_path"
get_cpu_status percent
EOF

    chmod +x "$script_path"
    echo "$script_path"
}

## Generate a script that outputs memory status
_generate_memory_script() {
    local script_path="${PIMPMYTMUX_CACHE_DIR}/scripts/memory.sh"
    local module_path="${PIMPMYTMUX_MODULES_DIR}/monitoring/memory.sh"

    mkdir -p "$(dirname "$script_path")"

    cat > "$script_path" << EOF
#!/usr/bin/env bash
source "$module_path"
get_memory_status percent
EOF

    chmod +x "$script_path"
    echo "$script_path"
}

## Generate a script that outputs battery status
_generate_battery_script() {
    local script_path="${PIMPMYTMUX_CACHE_DIR}/scripts/battery.sh"
    local module_path="${PIMPMYTMUX_MODULES_DIR}/monitoring/battery.sh"

    mkdir -p "$(dirname "$script_path")"

    cat > "$script_path" << EOF
#!/usr/bin/env bash
source "$module_path"
get_battery_status both
EOF

    chmod +x "$script_path"
    echo "$script_path"
}

## Generate a script that outputs network status
_generate_network_script() {
    local script_path="${PIMPMYTMUX_CACHE_DIR}/scripts/network.sh"
    local module_path="${PIMPMYTMUX_MODULES_DIR}/monitoring/network.sh"

    mkdir -p "$(dirname "$script_path")"

    cat > "$script_path" << EOF
#!/usr/bin/env bash
source "$module_path"
get_network_status ip
EOF

    chmod +x "$script_path"
    echo "$script_path"
}

## Generate a script that outputs weather
_generate_weather_script() {
    local script_path="${PIMPMYTMUX_CACHE_DIR}/scripts/weather.sh"
    local module_path="${PIMPMYTMUX_MODULES_DIR}/monitoring/weather.sh"

    mkdir -p "$(dirname "$script_path")"

    cat > "$script_path" << EOF
#!/usr/bin/env bash
export PIMPMYTMUX_CACHE_DIR="${PIMPMYTMUX_CACHE_DIR}"
source "$module_path"
get_weather_status
EOF

    chmod +x "$script_path"
    echo "$script_path"
}

## Generate a script that outputs git status
_generate_git_script() {
    local script_path="${PIMPMYTMUX_CACHE_DIR}/scripts/git.sh"
    local module_path="${PIMPMYTMUX_MODULES_DIR}/devtools/git-status.sh"

    mkdir -p "$(dirname "$script_path")"

    cat > "$script_path" << EOF
#!/usr/bin/env bash
export PIMPMYTMUX_CACHE_DIR="${PIMPMYTMUX_CACHE_DIR}"
export PIMPMYTMUX_LIB_DIR="${PIMPMYTMUX_LIB_DIR}"
source "$module_path"
get_git_status "\$(tmux display-message -p '#{pane_current_path}')"
EOF

    chmod +x "$script_path"
    echo "$script_path"
}

# -----------------------------------------------------------------------------
# Status bar configuration generation
# -----------------------------------------------------------------------------

## Generate monitoring configuration for tmux.conf
generate_monitoring_config() {
    local cpu_script memory_script battery_script network_script weather_script git_script

    cat << 'EOF'
# -----------------------------------------------------------------------------
# Monitoring Widgets
# -----------------------------------------------------------------------------

EOF

    # Generate scripts
    cpu_script=$(_generate_cpu_script)
    memory_script=$(_generate_memory_script)
    battery_script=$(_generate_battery_script)
    network_script=$(_generate_network_script)
    weather_script=$(_generate_weather_script)
    git_script=$(_generate_git_script)

    cat << EOF
# CPU usage
set -g @cpu_script "$cpu_script"

# Memory usage
set -g @memory_script "$memory_script"

# Battery status
set -g @battery_script "$battery_script"

# Network status
set -g @network_script "$network_script"

# Weather
set -g @weather_script "$weather_script"

# Git status
set -g @git_script "$git_script"

EOF
}

## Generate complete status bar with monitoring
generate_status_bar_config() {
    local position interval
    local left_len right_len

    position=$(get_config ".status_bar.position" "bottom")
    interval=$(get_config ".status_bar.interval" "5")
    left_len=$(get_config ".status_bar.left_length" "60")
    right_len=$(get_config ".status_bar.right_length" "120")

    # Check which components are enabled
    local monitoring_enabled git_enabled
    monitoring_enabled=$(get_config ".modules.monitoring.enabled" "true")
    git_enabled=$(get_config ".modules.devtools.git_status" "true")

    # Generate monitoring scripts
    generate_monitoring_config

    cat << EOF
# -----------------------------------------------------------------------------
# Status Bar Configuration
# -----------------------------------------------------------------------------

# Position and timing
set -g status-position ${position}
set -g status-interval ${interval}

# Length
set -g status-left-length ${left_len}
set -g status-right-length ${right_len}

EOF

    # Generate status-left
    cat << 'EOF'
# Status left: session and window info
set -g status-left "#{?client_prefix,#[reverse] PREFIX #[noreverse] ,} #S | #I:#W "

EOF

    # Generate status-right based on enabled modules
    local right_parts='%H:%M %d-%b'

    if [[ "$git_enabled" == "true" ]]; then
        right_parts="#(\${@git_script}) | ${right_parts}"
    fi

    if [[ "$monitoring_enabled" == "true" ]]; then
        local components
        components=$(get_config ".modules.monitoring.components" "cpu,memory")

        # Build right status based on components
        local monitoring_part=""

        if [[ "$components" == *"cpu"* ]]; then
            monitoring_part+='#(${@cpu_script}) '
        fi

        if [[ "$components" == *"memory"* ]]; then
            monitoring_part+='#(${@memory_script}) '
        fi

        if [[ "$components" == *"battery"* ]]; then
            monitoring_part+='#(${@battery_script}) '
        fi

        if [[ -n "$monitoring_part" ]]; then
            right_parts="${monitoring_part}| ${right_parts}"
        fi
    fi

    cat << EOF
# Status right: monitoring and time
set -g status-right " ${right_parts} "

EOF
}

## Generate prefix indicator
generate_prefix_indicator() {
    cat << 'EOF'
# Prefix indicator in status bar
set -g status-left "#{?client_prefix,#[bg=yellow]#[fg=black] PREFIX #[default] ,}#[bold] #S #[default]"

EOF
}
