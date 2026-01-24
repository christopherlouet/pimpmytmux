#!/usr/bin/env bash
# pimpmytmux - Conditional keybindings
# https://github.com/christopherlouet/pimpmytmux

# Guard against re-sourcing
[[ -n "${_PIMPMYTMUX_CONDITIONAL_LOADED:-}" ]] && return 0
_PIMPMYTMUX_CONDITIONAL_LOADED=1

# shellcheck source=lib/core.sh
source "${PIMPMYTMUX_LIB_DIR:-$(dirname "${BASH_SOURCE[0]}")}/core.sh"

# -----------------------------------------------------------------------------
# Condition Evaluation
# -----------------------------------------------------------------------------

## Evaluate a condition string
## Usage: evaluate_condition <condition>
## Returns: 0 if condition matches, 1 otherwise
## Conditions:
##   hostname:<pattern>  - Match against hostname
##   project:<type>      - Match project type (node, rust, go, python, etc.)
##   env:<VAR>=<value>   - Match environment variable value
##   env:<VAR>           - Check if environment variable exists
evaluate_condition() {
    local condition="$1"

    # Parse condition type
    local type="${condition%%:*}"
    local value="${condition#*:}"

    case "$type" in
        hostname)
            match_hostname "$value"
            ;;
        project)
            match_project_type "$value"
            ;;
        env)
            match_env_variable "$value"
            ;;
        *)
            log_debug "Unknown condition type: $type"
            return 1
            ;;
    esac
}

# -----------------------------------------------------------------------------
# Hostname Matching
# -----------------------------------------------------------------------------

## Parse hostname from condition
## Usage: parse_hostname_condition <condition>
parse_hostname_condition() {
    local condition="$1"
    echo "${condition#hostname:}"
}

## Match hostname against pattern
## Usage: match_hostname <pattern>
## Supports wildcards: * matches any string
match_hostname() {
    local pattern="$1"
    local current_host

    current_host=$(hostname 2>/dev/null || echo "unknown")

    # Exact wildcard matches everything
    if [[ "$pattern" == "*" ]]; then
        return 0
    fi

    # Pattern with wildcard at end (e.g., "server*")
    if [[ "$pattern" == *'*' ]]; then
        local prefix="${pattern%\*}"
        if [[ "$current_host" == "$prefix"* ]]; then
            return 0
        fi
        return 1
    fi

    # Pattern with wildcard at start (e.g., "*-prod")
    if [[ "$pattern" == '*'* ]]; then
        local suffix="${pattern#\*}"
        if [[ "$current_host" == *"$suffix" ]]; then
            return 0
        fi
        return 1
    fi

    # Exact match
    [[ "$current_host" == "$pattern" ]]
}

# -----------------------------------------------------------------------------
# Project Type Matching
# -----------------------------------------------------------------------------

## Parse project type from condition
## Usage: parse_project_condition <condition>
parse_project_condition() {
    local condition="$1"
    echo "${condition#project:}"
}

## Match project type in current directory
## Usage: match_project_type <type>
match_project_type() {
    local type="$1"
    local dir="${2:-$(pwd)}"

    case "$type" in
        node|nodejs|javascript|js)
            [[ -f "$dir/package.json" ]]
            ;;
        rust)
            [[ -f "$dir/Cargo.toml" ]]
            ;;
        go|golang)
            [[ -f "$dir/go.mod" ]]
            ;;
        python)
            [[ -f "$dir/pyproject.toml" ]] || [[ -f "$dir/setup.py" ]] || [[ -f "$dir/requirements.txt" ]]
            ;;
        ruby)
            [[ -f "$dir/Gemfile" ]]
            ;;
        java)
            [[ -f "$dir/pom.xml" ]] || [[ -f "$dir/build.gradle" ]]
            ;;
        php)
            [[ -f "$dir/composer.json" ]]
            ;;
        elixir)
            [[ -f "$dir/mix.exs" ]]
            ;;
        *)
            log_debug "Unknown project type: $type"
            return 1
            ;;
    esac
}

# -----------------------------------------------------------------------------
# Environment Variable Matching
# -----------------------------------------------------------------------------

## Match environment variable
## Usage: match_env_variable <spec>
## Spec formats:
##   VAR=value  - Check if VAR equals value
##   VAR        - Check if VAR exists (not empty)
match_env_variable() {
    local spec="$1"

    if [[ "$spec" == *"="* ]]; then
        # Check value
        local var="${spec%%=*}"
        local expected="${spec#*=}"
        local actual="${!var:-}"

        [[ "$actual" == "$expected" ]]
    else
        # Check existence
        local var="$spec"
        [[ -n "${!var:-}" ]]
    fi
}

# -----------------------------------------------------------------------------
# Conditional Keybindings
# -----------------------------------------------------------------------------

## Get conditional keybindings from config
## Usage: get_conditional_keybindings <config_file>
get_conditional_keybindings() {
    local config_file="${1:-$PIMPMYTMUX_CONFIG_FILE}"

    if [[ ! -f "$config_file" ]]; then
        return 0
    fi

    # Check if yq is available
    if ! check_command yq; then
        log_debug "yq not available, skipping conditional keybindings"
        return 0
    fi

    local yq_type
    yq_type=$(detect_yq_version 2>/dev/null || echo "go")

    # Get number of conditional entries
    local count
    if [[ "$yq_type" == "go" ]]; then
        count=$(yq eval '.keybindings.conditional | length // 0' "$config_file" 2>/dev/null || echo "0")
    else
        return 0
    fi

    if [[ "$count" == "0" ]] || [[ -z "$count" ]]; then
        return 0
    fi

    # Process each conditional entry
    local i=0
    local found_any=false
    while [[ $i -lt $count ]]; do
        local condition
        condition=$(yq eval ".keybindings.conditional[$i].condition" "$config_file" 2>/dev/null)

        if [[ -n "$condition" ]] && [[ "$condition" != "null" ]]; then
            if evaluate_condition "$condition"; then
                # Output bindings for matching condition
                yq eval ".keybindings.conditional[$i].bindings | to_entries | .[] | .key + \"=\" + .value" "$config_file" 2>/dev/null || true
                found_any=true
            fi
        fi

        ((i++))
    done

    return 0
}

## Merge base keybindings with conditional ones
## Usage: merge_keybindings <base> <conditional>
merge_keybindings() {
    local base="$1"
    local conditional="$2"

    # Output base bindings
    if [[ -n "$base" ]]; then
        echo "$base"
    fi

    # Output conditional bindings (will override base if same key)
    if [[ -n "$conditional" ]]; then
        echo "$conditional"
    fi
}

## Generate conditional keybindings as tmux commands
## Usage: generate_conditional_keybindings <config_file>
generate_conditional_keybindings() {
    local config_file="${1:-$PIMPMYTMUX_CONFIG_FILE}"

    local bindings
    bindings=$(get_conditional_keybindings "$config_file")

    if [[ -z "$bindings" ]]; then
        return 0
    fi

    echo "# Conditional keybindings"

    while IFS='=' read -r key value; do
        if [[ -n "$key" ]] && [[ -n "$value" ]]; then
            # Check if value contains an action (has spaces = key + command)
            if [[ "$value" == *" "* ]]; then
                # Full binding: key action
                local bind_key="${value%% *}"
                local bind_action="${value#* }"
                echo "# $key"
                echo "bind $bind_key $bind_action"
            else
                # Just a key, needs to be mapped to a default action
                echo "# $key = $value"
            fi
        fi
    done <<< "$bindings"
}

## Apply conditional keybindings to running tmux
## Usage: apply_conditional_keybindings
apply_conditional_keybindings() {
    # Only run if inside tmux
    if [[ -z "${TMUX:-}" ]]; then
        log_debug "Not inside tmux, skipping conditional keybindings"
        return 0
    fi

    local bindings
    bindings=$(generate_conditional_keybindings)

    if [[ -z "$bindings" ]]; then
        return 0
    fi

    # Apply each binding
    while IFS= read -r line; do
        if [[ "$line" == "bind "* ]]; then
            tmux $line 2>/dev/null || true
        fi
    done <<< "$bindings"

    log_debug "Applied conditional keybindings"
}
