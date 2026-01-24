#!/usr/bin/env bats
# pimpmytmux - Tests for lib/config.sh

load 'test_helper'

setup() {
    # Call parent setup
    mkdir -p "$PIMPMYTMUX_CONFIG_DIR"
    mkdir -p "$PIMPMYTMUX_DATA_DIR"
    mkdir -p "$PIMPMYTMUX_CACHE_DIR"

    # Load libraries
    load_lib 'core'
    load_lib 'config'
}

# -----------------------------------------------------------------------------
# YAML detection tests
# -----------------------------------------------------------------------------

@test "detect_yq_version returns empty when yq not installed" {
    # Skip if yq is actually installed
    if command -v yq &>/dev/null; then
        skip "yq is installed"
    fi
    run detect_yq_version
    assert_success
    [[ -z "$output" ]]
}

@test "detect_yq_version returns go or python when yq installed" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi
    run detect_yq_version
    assert_success
    [[ "$output" =~ ^(go|python)$ ]]
}

# -----------------------------------------------------------------------------
# Config value tests
# -----------------------------------------------------------------------------

@test "get_config returns default when config file missing" {
    export PIMPMYTMUX_CONFIG_FILE="/nonexistent/config.yaml"
    result=$(get_config ".theme" "default_theme")
    [[ "$result" == "default_theme" ]]
}

@test "get_config returns value from config file" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config 'theme: matrix'
    export PIMPMYTMUX_CONFIG_FILE="${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml"

    result=$(get_config ".theme" "default")
    [[ "$result" == "matrix" ]]
}

@test "get_config returns default for missing key" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config 'theme: matrix'
    export PIMPMYTMUX_CONFIG_FILE="${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml"

    result=$(get_config ".nonexistent.key" "fallback")
    [[ "$result" == "fallback" ]]
}

@test "config_enabled returns true for true value" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config '
modules:
  sessions:
    enabled: true
'
    export PIMPMYTMUX_CONFIG_FILE="${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml"

    run config_enabled ".modules.sessions.enabled"
    assert_success
}

@test "config_enabled returns false for false value" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config '
modules:
  sessions:
    enabled: false
'
    export PIMPMYTMUX_CONFIG_FILE="${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml"

    run config_enabled ".modules.sessions.enabled"
    assert_failure
}

# -----------------------------------------------------------------------------
# Validation tests
# -----------------------------------------------------------------------------

@test "validate_config fails for missing file" {
    run validate_config "/nonexistent/config.yaml"
    assert_failure
}

@test "validate_config succeeds for valid config" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config
    run validate_config "${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml"
    assert_success
}

# -----------------------------------------------------------------------------
# Generation tests
# -----------------------------------------------------------------------------

@test "generate_tmux_conf creates output file" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config
    local output_file="${PIMPMYTMUX_CONFIG_DIR}/tmux.conf"

    run generate_tmux_conf "${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml" "$output_file"
    assert_success
    assert_file_exists "$output_file"
}

@test "generate_tmux_conf includes prefix setting" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config '
general:
  prefix: C-a
'
    local output_file="${PIMPMYTMUX_CONFIG_DIR}/tmux.conf"

    run generate_tmux_conf "${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml" "$output_file"
    assert_success

    grep -q "prefix C-a" "$output_file"
}

@test "generate_tmux_conf includes mouse setting" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config '
general:
  mouse: true
'
    local output_file="${PIMPMYTMUX_CONFIG_DIR}/tmux.conf"

    run generate_tmux_conf "${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml" "$output_file"
    assert_success

    grep -q "mouse on" "$output_file"
}

@test "generate_tmux_conf dry run does not create file" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config
    local output_file="${PIMPMYTMUX_CONFIG_DIR}/tmux.conf"

    # Make sure file doesn't exist
    rm -f "$output_file"

    run generate_tmux_conf "${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml" "$output_file" "true"
    assert_success

    [[ ! -f "$output_file" ]]
}

@test "generate_tmux_conf includes vim keybindings when enabled" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config '
modules:
  navigation:
    vim_mode: true
'
    local output_file="${PIMPMYTMUX_CONFIG_DIR}/tmux.conf"

    run generate_tmux_conf "${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml" "$output_file"
    assert_success

    grep -q "bind h select-pane -L" "$output_file"
    grep -q "bind j select-pane -D" "$output_file"
    grep -q "bind k select-pane -U" "$output_file"
    grep -q "bind l select-pane -R" "$output_file"
}

@test "generate_tmux_conf includes reload binding" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config '
keybindings:
  reload: r
'
    local output_file="${PIMPMYTMUX_CONFIG_DIR}/tmux.conf"

    run generate_tmux_conf "${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml" "$output_file"
    assert_success

    grep -q "bind r source-file" "$output_file"
}

# -----------------------------------------------------------------------------
# Simple YAML fallback tests
# -----------------------------------------------------------------------------

@test "_yaml_get_simple extracts top-level key" {
    local config_file="${PIMPMYTMUX_TEST_DIR}/simple.yaml"
    echo "theme: dracula" > "$config_file"

    result=$(_yaml_get_simple "$config_file" "theme")
    [[ "$result" == "dracula" ]]
}

@test "_yaml_get_simple handles quoted values" {
    local config_file="${PIMPMYTMUX_TEST_DIR}/simple.yaml"
    echo 'name: "hello world"' > "$config_file"

    result=$(_yaml_get_simple "$config_file" "name")
    [[ "$result" == '"hello world"' ]]
}
