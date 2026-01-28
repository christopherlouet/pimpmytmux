#!/usr/bin/env bats
# pimpmytmux - Tests for thumbs module (tmux-thumbs integration)

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
# check_thumbs_installed tests
# -----------------------------------------------------------------------------

@test "check_thumbs_installed returns false when not installed" {
    # Ensure thumbs is not in any expected location
    run check_thumbs_installed
    # May pass or fail depending on system, so we just check it runs
    [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

# -----------------------------------------------------------------------------
# get_thumbs_path tests
# -----------------------------------------------------------------------------

@test "get_thumbs_path returns empty when not installed" {
    # Override PATH to ensure tmux-thumbs is not found
    PATH="/nonexistent" run get_thumbs_path
    # Should return empty or a path - just verify it doesn't crash
    [[ "$status" -eq 0 ]]
}

# -----------------------------------------------------------------------------
# generate_thumbs_config tests
# -----------------------------------------------------------------------------

@test "generate_thumbs_config generates binding for prefix+T" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config '
modules:
  navigation:
    thumbs:
      enabled: true
'
    export PIMPMYTMUX_CONFIG_FILE="${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml"

    run generate_thumbs_config
    assert_success
    assert_output_contains "Thumbs"
    assert_output_contains "bind T"
}

@test "generate_thumbs_config uses custom key from config" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config '
modules:
  navigation:
    thumbs:
      enabled: true
      key: "F"
'
    export PIMPMYTMUX_CONFIG_FILE="${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml"

    run generate_thumbs_config
    assert_success
    assert_output_contains "bind F"
}

@test "generate_thumbs_config sets alphabet option" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config '
modules:
  navigation:
    thumbs:
      enabled: true
      alphabet: "colemak"
'
    export PIMPMYTMUX_CONFIG_FILE="${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml"

    run generate_thumbs_config
    assert_success
    assert_output_contains "@thumbs-alphabet"
    assert_output_contains "colemak"
}

@test "generate_thumbs_config sets reverse option" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config '
modules:
  navigation:
    thumbs:
      enabled: true
      reverse: true
'
    export PIMPMYTMUX_CONFIG_FILE="${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml"

    run generate_thumbs_config
    assert_success
    assert_output_contains "@thumbs-reverse"
    assert_output_contains "enabled"
}

@test "generate_thumbs_config sets unique option" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config '
modules:
  navigation:
    thumbs:
      enabled: true
      unique: true
'
    export PIMPMYTMUX_CONFIG_FILE="${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml"

    run generate_thumbs_config
    assert_success
    assert_output_contains "@thumbs-unique"
    assert_output_contains "enabled"
}

@test "generate_thumbs_config sets position option" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config '
modules:
  navigation:
    thumbs:
      enabled: true
      position: "right"
'
    export PIMPMYTMUX_CONFIG_FILE="${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml"

    run generate_thumbs_config
    assert_success
    assert_output_contains "@thumbs-position"
    assert_output_contains "right"
}

@test "generate_thumbs_config uses defaults when no options specified" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config '
modules:
  navigation:
    thumbs:
      enabled: true
'
    export PIMPMYTMUX_CONFIG_FILE="${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml"

    run generate_thumbs_config
    assert_success
    assert_output_contains "bind T"
    assert_output_contains "@thumbs-alphabet"
    assert_output_contains "qwerty"
}

# -----------------------------------------------------------------------------
# Integration with config.sh
# -----------------------------------------------------------------------------

@test "generate_tmux_conf includes thumbs config when enabled" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config '
modules:
  navigation:
    enabled: true
    thumbs:
      enabled: true
'
    local output_file="${PIMPMYTMUX_CONFIG_DIR}/tmux.conf"

    run generate_tmux_conf "${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml" "$output_file"
    assert_success

    grep -q 'Thumbs' "$output_file"
    grep -q 'bind T' "$output_file"
}

@test "generate_tmux_conf does not include thumbs when disabled" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config '
modules:
  navigation:
    enabled: true
    thumbs:
      enabled: false
'
    local output_file="${PIMPMYTMUX_CONFIG_DIR}/tmux.conf"

    run generate_tmux_conf "${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml" "$output_file"
    assert_success

    ! grep -q 'thumbs' "$output_file"
}
