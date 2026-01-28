#!/usr/bin/env bats
# pimpmytmux - Tests for clipboard integration (copy_command)

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
# get_copy_command tests
# -----------------------------------------------------------------------------

@test "get_copy_command returns empty when no platform config" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config 'theme: matrix'
    export PIMPMYTMUX_CONFIG_FILE="${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml"

    result=$(get_copy_command)
    [[ -z "$result" ]]
}

@test "get_copy_command returns linux copy_command on linux" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config '
platform:
  linux:
    copy_command: "wl-copy"
'
    export PIMPMYTMUX_CONFIG_FILE="${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml"

    # Mock get_platform to return linux
    get_platform() { echo "linux"; }
    export -f get_platform

    result=$(get_copy_command)
    [[ "$result" == "wl-copy" ]]
}

@test "get_copy_command returns macos copy_command on macos" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config '
platform:
  macos:
    copy_command: "pbcopy"
'
    export PIMPMYTMUX_CONFIG_FILE="${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml"

    # Mock get_platform to return macos
    get_platform() { echo "macos"; }
    export -f get_platform

    result=$(get_copy_command)
    [[ "$result" == "pbcopy" ]]
}

@test "get_copy_command returns wsl copy_command on wsl" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config '
platform:
  wsl:
    copy_command: "clip.exe"
'
    export PIMPMYTMUX_CONFIG_FILE="${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml"

    # Mock get_platform to return wsl
    get_platform() { echo "wsl"; }
    export -f get_platform

    result=$(get_copy_command)
    [[ "$result" == "clip.exe" ]]
}

@test "get_copy_command handles xclip with options" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config '
platform:
  linux:
    copy_command: "xclip -selection clipboard"
'
    export PIMPMYTMUX_CONFIG_FILE="${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml"

    # Mock get_platform to return linux
    get_platform() { echo "linux"; }
    export -f get_platform

    result=$(get_copy_command)
    [[ "$result" == "xclip -selection clipboard" ]]
}

# -----------------------------------------------------------------------------
# tmux.conf generation with copy_command tests
# -----------------------------------------------------------------------------

@test "generate_tmux_conf uses copy-pipe-and-cancel when copy_command configured" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config '
modules:
  navigation:
    vim_mode: true
platform:
  linux:
    copy_command: "wl-copy"
'
    local output_file="${PIMPMYTMUX_CONFIG_DIR}/tmux.conf"

    # Mock get_platform to return linux
    get_platform() { echo "linux"; }
    export -f get_platform

    run generate_tmux_conf "${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml" "$output_file"
    assert_success

    # Should use copy-pipe-and-cancel with wl-copy
    grep -q 'copy-pipe-and-cancel.*wl-copy' "$output_file"
}

@test "generate_tmux_conf uses copy-selection-and-cancel when no copy_command" {
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

    # Should use copy-selection-and-cancel (default behavior)
    grep -q 'copy-selection-and-cancel' "$output_file"
    # Should NOT have copy-pipe
    ! grep -q 'copy-pipe-and-cancel' "$output_file"
}

@test "generate_tmux_conf includes Y binding with copy_command" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config '
modules:
  navigation:
    enabled: true
    vim_mode: true
platform:
  linux:
    copy_command: "wl-copy"
'
    local output_file="${PIMPMYTMUX_CONFIG_DIR}/tmux.conf"

    # Mock get_platform to return linux
    get_platform() { echo "linux"; }
    export -f get_platform

    run generate_tmux_conf "${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml" "$output_file"
    assert_success

    # The vim-mode module should also use copy-pipe for Y binding
    # Y copies to end of line, should also go to clipboard
    grep -q 'copy-mode-vi Y' "$output_file"
}

# -----------------------------------------------------------------------------
# Edge cases
# -----------------------------------------------------------------------------

@test "get_copy_command returns empty for unknown platform" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config '
platform:
  linux:
    copy_command: "wl-copy"
'
    export PIMPMYTMUX_CONFIG_FILE="${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml"

    # Mock get_platform to return unknown
    get_platform() { echo "unknown"; }
    export -f get_platform

    result=$(get_copy_command)
    [[ -z "$result" ]]
}

@test "get_copy_command handles missing platform section gracefully" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config '
theme: matrix
general:
  mouse: true
'
    export PIMPMYTMUX_CONFIG_FILE="${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml"

    # Should not error, just return empty
    result=$(get_copy_command)
    [[ -z "$result" ]]
}
