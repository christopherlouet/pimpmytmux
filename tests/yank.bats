#!/usr/bin/env bats
# pimpmytmux - Tests for yank bindings (tmux-yank integration)

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
# generate_yank_bindings tests
# -----------------------------------------------------------------------------

@test "generate_yank_bindings produces nothing when copy_cmd is empty" {
    run generate_yank_bindings ""
    assert_success
    [[ -z "$output" ]]
}

@test "generate_yank_bindings generates prefix+y binding with copy command" {
    run generate_yank_bindings "wl-copy"
    assert_success
    assert_output_contains "bind y run-shell"
    assert_output_contains "wl-copy"
}

@test "generate_yank_bindings generates prefix+Y binding for pwd" {
    run generate_yank_bindings "wl-copy"
    assert_success
    assert_output_contains "bind Y run-shell"
    assert_output_contains "pane_current_path"
    assert_output_contains "wl-copy"
}

@test "generate_yank_bindings generates section header" {
    run generate_yank_bindings "pbcopy"
    assert_success
    assert_output_contains "Yank"
}

@test "generate_yank_bindings works with xclip multi-word command" {
    run generate_yank_bindings "xclip -selection clipboard"
    assert_success
    assert_output_contains "xclip -selection clipboard"
}

# -----------------------------------------------------------------------------
# generate_vim_copy_mode with stay_in_copy tests
# -----------------------------------------------------------------------------

@test "generate_vim_copy_mode uses copy-pipe-and-cancel by default" {
    run generate_vim_copy_mode "wl-copy" "false"
    assert_success
    assert_output_contains "copy-pipe-and-cancel"
}

@test "generate_vim_copy_mode uses copy-pipe when stay_in_copy is true" {
    run generate_vim_copy_mode "wl-copy" "true"
    assert_success
    assert_output_contains 'copy-pipe "wl-copy"'
    refute_output_contains "copy-pipe-and-cancel"
}

@test "generate_vim_copy_mode defaults stay_in_copy to false" {
    run generate_vim_copy_mode "wl-copy"
    assert_success
    assert_output_contains "copy-pipe-and-cancel"
}

@test "generate_vim_copy_mode without copy_cmd uses copy-selection-and-cancel" {
    run generate_vim_copy_mode "" "false"
    assert_success
    assert_output_contains "copy-selection-and-cancel"
    refute_output_contains "copy-pipe"
}

@test "generate_vim_copy_mode without copy_cmd ignores stay_in_copy" {
    run generate_vim_copy_mode "" "true"
    assert_success
    assert_output_contains "copy-selection-and-cancel"
    refute_output_contains "copy-pipe"
}

# -----------------------------------------------------------------------------
# generate_vim_mode_config with stay_in_copy tests
# -----------------------------------------------------------------------------

@test "generate_vim_mode_config passes stay_in_copy to copy mode" {
    run generate_vim_mode_config "wl-copy" "true"
    assert_success
    assert_output_contains 'copy-pipe "wl-copy"'
    refute_output_contains "copy-pipe-and-cancel"
}

@test "generate_vim_mode_config calls generate_yank_bindings" {
    run generate_vim_mode_config "wl-copy"
    assert_success
    assert_output_contains "Yank"
    assert_output_contains "bind y run-shell"
}

@test "generate_vim_mode_config skips yank bindings without copy command" {
    run generate_vim_mode_config ""
    assert_success
    refute_output_contains "bind y run-shell"
}

# -----------------------------------------------------------------------------
# Integration with config.sh
# -----------------------------------------------------------------------------

@test "generate_tmux_conf includes yank bindings when yank enabled" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config '
modules:
  navigation:
    enabled: true
    vim_mode: true
    yank:
      enabled: true
platform:
  linux:
    copy_command: "wl-copy"
'
    local output_file="${PIMPMYTMUX_CONFIG_DIR}/tmux.conf"

    get_platform() { echo "linux"; }
    export -f get_platform

    run generate_tmux_conf "${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml" "$output_file"
    assert_success

    grep -q 'bind y run-shell' "$output_file"
    grep -q 'bind Y run-shell' "$output_file"
}

@test "generate_tmux_conf uses copy-pipe when stay_in_copy_mode enabled" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config '
modules:
  navigation:
    enabled: true
    vim_mode: true
    yank:
      enabled: true
      stay_in_copy_mode: true
platform:
  linux:
    copy_command: "wl-copy"
'
    local output_file="${PIMPMYTMUX_CONFIG_DIR}/tmux.conf"

    get_platform() { echo "linux"; }
    export -f get_platform

    run generate_tmux_conf "${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml" "$output_file"
    assert_success

    # Should have copy-pipe (without -and-cancel) in vim copy mode section
    grep -q 'copy-pipe "wl-copy"' "$output_file"
}

@test "generate_tmux_conf does not include yank bindings when yank disabled" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config '
modules:
  navigation:
    enabled: true
    vim_mode: true
    yank:
      enabled: false
platform:
  linux:
    copy_command: "wl-copy"
'
    local output_file="${PIMPMYTMUX_CONFIG_DIR}/tmux.conf"

    get_platform() { echo "linux"; }
    export -f get_platform

    run generate_tmux_conf "${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml" "$output_file"
    assert_success

    # Yank prefix bindings should not be present
    ! grep -q 'bind y run-shell' "$output_file"
}
