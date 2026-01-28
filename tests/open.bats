#!/usr/bin/env bats
# pimpmytmux - Tests for open module (tmux-open integration)

load 'test_helper'

setup() {
    mkdir -p "$PIMPMYTMUX_CONFIG_DIR"
    mkdir -p "$PIMPMYTMUX_DATA_DIR"
    mkdir -p "$PIMPMYTMUX_CACHE_DIR"

    # Load libraries
    load_lib 'core'
    load_lib 'config'
}

# -----------------------------------------------------------------------------
# get_open_command tests
# -----------------------------------------------------------------------------

@test "get_open_command returns xdg-open on linux" {
    get_platform() { echo "linux"; }
    export -f get_platform

    # No custom config
    create_test_config '
modules:
  navigation:
    open:
      enabled: true
'
    export PIMPMYTMUX_CONFIG_FILE="${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml"

    run get_open_command
    assert_success
    assert_output_contains "xdg-open"
}

@test "get_open_command returns open on macos" {
    get_platform() { echo "macos"; }
    export -f get_platform

    create_test_config '
modules:
  navigation:
    open:
      enabled: true
'
    export PIMPMYTMUX_CONFIG_FILE="${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml"

    run get_open_command
    assert_success
    assert_output "open"
}

@test "get_open_command uses custom command from config" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config '
modules:
  navigation:
    open:
      enabled: true
      open_command: "my-custom-open"
'
    export PIMPMYTMUX_CONFIG_FILE="${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml"

    run get_open_command
    assert_success
    assert_output "my-custom-open"
}

# -----------------------------------------------------------------------------
# get_editor_command tests
# -----------------------------------------------------------------------------

@test "get_editor_command uses config value when set" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config '
modules:
  navigation:
    open:
      enabled: true
      editor: "code"
'
    export PIMPMYTMUX_CONFIG_FILE="${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml"

    run get_editor_command
    assert_success
    assert_output "code"
}

@test "get_editor_command falls back to EDITOR env var" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config '
modules:
  navigation:
    open:
      enabled: true
'
    export PIMPMYTMUX_CONFIG_FILE="${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml"
    export EDITOR="nano"

    run get_editor_command
    assert_success
    assert_output "nano"

    unset EDITOR
}

@test "get_editor_command falls back to vi when no EDITOR" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config '
modules:
  navigation:
    open:
      enabled: true
'
    export PIMPMYTMUX_CONFIG_FILE="${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml"
    unset EDITOR

    run get_editor_command
    assert_success
    # Should return nvim, vim, or vi depending on what's installed
    [[ "$output" == "nvim" || "$output" == "vim" || "$output" == "vi" ]]
}

# -----------------------------------------------------------------------------
# generate_open_bindings tests
# -----------------------------------------------------------------------------

@test "generate_open_bindings generates o binding for open" {
    run generate_open_bindings "xdg-open" "nvim" "https://www.google.com/search?q="
    assert_success
    assert_output_contains "copy-mode-vi o"
    assert_output_contains "xdg-open"
}

@test "generate_open_bindings generates C-o binding for editor" {
    run generate_open_bindings "xdg-open" "nvim" "https://www.google.com/search?q="
    assert_success
    assert_output_contains "copy-mode-vi C-o"
    assert_output_contains "nvim"
}

@test "generate_open_bindings generates S binding for search" {
    run generate_open_bindings "xdg-open" "nvim" "https://www.google.com/search?q="
    assert_success
    assert_output_contains "copy-mode-vi S"
    assert_output_contains "google.com"
}

@test "generate_open_bindings uses custom search engine" {
    run generate_open_bindings "xdg-open" "nvim" "https://duckduckgo.com/?q="
    assert_success
    assert_output_contains "duckduckgo.com"
}

@test "generate_open_bindings includes section header" {
    run generate_open_bindings "open" "vim" "https://www.google.com/search?q="
    assert_success
    assert_output_contains "Open"
}

# -----------------------------------------------------------------------------
# generate_open_config tests
# -----------------------------------------------------------------------------

@test "generate_open_config generates complete configuration" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config '
modules:
  navigation:
    open:
      enabled: true
'
    export PIMPMYTMUX_CONFIG_FILE="${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml"

    get_platform() { echo "linux"; }
    export -f get_platform

    run generate_open_config
    assert_success
    assert_output_contains "copy-mode-vi o"
    assert_output_contains "copy-mode-vi C-o"
    assert_output_contains "copy-mode-vi S"
}

@test "generate_open_config uses custom search engine from config" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config '
modules:
  navigation:
    open:
      enabled: true
      search_engine: "https://duckduckgo.com/?q="
'
    export PIMPMYTMUX_CONFIG_FILE="${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml"

    get_platform() { echo "linux"; }
    export -f get_platform

    run generate_open_config
    assert_success
    assert_output_contains "duckduckgo.com"
}

# -----------------------------------------------------------------------------
# Integration with config.sh
# -----------------------------------------------------------------------------

@test "generate_tmux_conf includes open config when enabled" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config '
modules:
  navigation:
    enabled: true
    open:
      enabled: true
'
    local output_file="${PIMPMYTMUX_CONFIG_DIR}/tmux.conf"

    get_platform() { echo "linux"; }
    export -f get_platform

    run generate_tmux_conf "${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml" "$output_file"
    assert_success

    grep -q 'copy-mode-vi o' "$output_file"
    grep -q 'copy-mode-vi C-o' "$output_file"
    grep -q 'copy-mode-vi S' "$output_file"
}

@test "generate_tmux_conf does not include open when disabled" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config '
modules:
  navigation:
    enabled: true
    open:
      enabled: false
'
    local output_file="${PIMPMYTMUX_CONFIG_DIR}/tmux.conf"

    run generate_tmux_conf "${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml" "$output_file"
    assert_success

    ! grep -q 'copy-mode-vi o.*send-keys.*copy-pipe' "$output_file"
}
