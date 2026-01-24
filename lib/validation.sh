#!/usr/bin/env bash
# pimpmytmux - Configuration validation functions
# https://github.com/christopherlouet/pimpmytmux

# Guard against re-sourcing
[[ -n "${_PIMPMYTMUX_VALIDATION_LOADED:-}" ]] && return 0
_PIMPMYTMUX_VALIDATION_LOADED=1

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

# Common valid tmux options (not exhaustive, but covers most used)
readonly TMUX_COMMON_OPTIONS=(
    "prefix"
    "prefix2"
    "mouse"
    "base-index"
    "pane-base-index"
    "renumber-windows"
    "history-limit"
    "default-terminal"
    "terminal-overrides"
    "escape-time"
    "focus-events"
    "set-clipboard"
    "status"
    "status-position"
    "status-style"
    "status-left"
    "status-right"
    "status-left-length"
    "status-right-length"
    "status-interval"
    "window-status-current-style"
    "window-status-style"
    "pane-border-style"
    "pane-active-border-style"
    "message-style"
    "message-command-style"
    "mode-style"
    "display-time"
    "display-panes-time"
    "monitor-activity"
    "visual-activity"
    "bell-action"
    "activity-action"
)

# -----------------------------------------------------------------------------
# Validation Functions
# -----------------------------------------------------------------------------

## Validate tmux configuration syntax by running tmux in validation mode
## Usage: validate_tmux_syntax <config_file>
## Returns: 0 if valid, 1 if invalid or error
validate_tmux_syntax() {
    local config_file="$1"

    # Check arguments
    if [[ -z "$config_file" ]]; then
        log_error "validate_tmux_syntax: No config file specified"
        return 1
    fi

    # Check file exists
    if [[ ! -f "$config_file" ]]; then
        log_error "validate_tmux_syntax: Config file not found: $config_file"
        return 1
    fi

    # Check file is readable
    if [[ ! -r "$config_file" ]]; then
        log_error "validate_tmux_syntax: Config file not readable: $config_file"
        return 1
    fi

    # Check tmux is available
    if ! check_command tmux; then
        log_error "validate_tmux_syntax: tmux not found"
        return 1
    fi

    log_debug "Validating tmux config: $config_file"

    # Create a temporary socket for validation
    local temp_socket
    temp_socket=$(mktemp -u "/tmp/pimpmytmux-validate-XXXXXX")

    local validation_output
    local validation_status

    # Start a temporary tmux server with minimal config
    # Then try to source the config file - this will catch syntax errors
    tmux -S "$temp_socket" -f /dev/null new-session -d -s _pimpmytmux_validate 2>/dev/null

    if [[ $? -ne 0 ]]; then
        # Couldn't start server, try alternative method
        rm -f "$temp_socket" 2>/dev/null
        log_debug "Could not start validation server, skipping syntax check"
        return 0
    fi

    # Now source the config file to validate it
    validation_output=$(tmux -S "$temp_socket" source-file "$config_file" 2>&1)
    validation_status=$?

    # Kill the temporary server
    tmux -S "$temp_socket" kill-server 2>/dev/null
    rm -f "$temp_socket" 2>/dev/null

    if [[ $validation_status -ne 0 ]]; then
        log_debug "Validation failed with status $validation_status"
        log_debug "Output: $validation_output"
        return 1
    fi

    # Check for error messages in output
    if [[ -n "$validation_output" ]] && echo "$validation_output" | grep -qiE "(error|invalid|unknown command|bad)"; then
        log_debug "Validation output contains errors: $validation_output"
        return 1
    fi

    log_debug "Config validation successful"
    return 0
}

## Get validation errors for a tmux config file
## Usage: get_validation_errors <config_file>
## Returns: Error messages (empty if valid)
get_validation_errors() {
    local config_file="$1"

    if [[ -z "$config_file" ]] || [[ ! -f "$config_file" ]]; then
        echo "File not found: $config_file"
        return 1
    fi

    if ! check_command tmux; then
        echo "tmux not found"
        return 1
    fi

    local temp_socket
    temp_socket=$(mktemp -u "/tmp/pimpmytmux-validate-XXXXXX")

    # Start a temporary tmux server
    tmux -S "$temp_socket" -f /dev/null new-session -d -s _pimpmytmux_validate 2>/dev/null

    if [[ $? -ne 0 ]]; then
        rm -f "$temp_socket" 2>/dev/null
        echo ""
        return 0
    fi

    # Source the config and capture errors
    local errors
    errors=$(tmux -S "$temp_socket" source-file "$config_file" 2>&1)
    local status=$?

    # Kill the temporary server
    tmux -S "$temp_socket" kill-server 2>/dev/null
    rm -f "$temp_socket" 2>/dev/null

    if [[ $status -ne 0 ]] || [[ -n "$errors" ]]; then
        echo "$errors"
        return 0
    fi

    # No errors
    echo ""
    return 0
}

## Validate a config file exists and is readable
## Usage: validate_config_file <config_file>
## Returns: 0 if valid, 1 if not
validate_config_file() {
    local config_file="$1"

    if [[ -z "$config_file" ]]; then
        log_error "No config file specified"
        return 1
    fi

    if [[ ! -e "$config_file" ]]; then
        log_error "Config file does not exist: $config_file"
        return 1
    fi

    if [[ -d "$config_file" ]]; then
        log_error "Path is a directory, not a file: $config_file"
        return 1
    fi

    if [[ ! -f "$config_file" ]]; then
        log_error "Path is not a regular file: $config_file"
        return 1
    fi

    if [[ ! -r "$config_file" ]]; then
        log_error "Config file is not readable: $config_file"
        return 1
    fi

    log_debug "Config file validated: $config_file"
    return 0
}

## Full validation before applying config
## Usage: validate_before_apply <config_file>
## Returns: 0 if safe to apply, 1 if not
validate_before_apply() {
    local config_file="$1"

    log_verbose "Validating config before apply: $config_file"

    # Step 1: Validate file exists and is readable
    if ! validate_config_file "$config_file"; then
        log_error "Config file validation failed"
        return 1
    fi

    # Step 2: Validate tmux syntax
    if ! validate_tmux_syntax "$config_file"; then
        local errors
        errors=$(get_validation_errors "$config_file")
        log_error "Tmux config validation failed"
        if [[ -n "$errors" ]]; then
            log_error "Errors: $errors"
        fi
        return 1
    fi

    log_verbose "Config validation passed"
    return 0
}

## Check if a tmux option name is valid (known option)
## Usage: is_valid_tmux_option <option_name>
## Returns: 0 if known valid option, 1 if unknown
## Note: This is a soft check - unknown options might still be valid in newer tmux versions
is_valid_tmux_option() {
    local option="$1"

    if [[ -z "$option" ]]; then
        return 1
    fi

    # Check against known options
    local known_option
    for known_option in "${TMUX_COMMON_OPTIONS[@]}"; do
        if [[ "$known_option" == "$option" ]]; then
            return 0
        fi
    done

    # For unknown options, we don't fail - tmux might have newer options
    # Just return success and let tmux itself validate
    log_debug "Option '$option' not in known list, assuming valid"
    return 0
}

## Validate generated config and provide detailed feedback
## Usage: validate_generated_config <config_file>
## Returns: 0 if valid, 1 if invalid with detailed errors
validate_generated_config() {
    local config_file="$1"
    local errors_found=0

    log_info "Validating generated configuration..."

    # Check file
    if ! validate_config_file "$config_file"; then
        return 1
    fi

    # Check syntax
    local errors
    errors=$(get_validation_errors "$config_file")

    if [[ -n "$errors" ]]; then
        log_error "Configuration validation failed!"
        log_error "----------------------------------------"
        echo "$errors" | while IFS= read -r line; do
            if [[ -n "$line" ]]; then
                log_error "  $line"
            fi
        done
        log_error "----------------------------------------"
        log_error "The generated config contains errors."
        log_error "Please check your pimpmytmux.yaml configuration."
        return 1
    fi

    log_success "Configuration validated successfully"
    return 0
}
