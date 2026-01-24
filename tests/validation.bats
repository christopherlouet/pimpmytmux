#!/usr/bin/env bats
# pimpmytmux - Tests for lib/validation.sh

load 'test_helper'

setup() {
    mkdir -p "$PIMPMYTMUX_CONFIG_DIR"
    mkdir -p "$PIMPMYTMUX_DATA_DIR"
    mkdir -p "$PIMPMYTMUX_CACHE_DIR"

    # Load required libraries
    load_lib 'core'
    load_lib 'validation'
}

# -----------------------------------------------------------------------------
# validate_tmux_syntax tests
# -----------------------------------------------------------------------------

@test "validate_tmux_syntax returns 0 for valid tmux config" {
    local config_file="${PIMPMYTMUX_TEST_DIR}/valid.conf"
    cat > "$config_file" << 'EOF'
# Valid tmux configuration
set -g prefix C-a
set -g mouse on
set -g base-index 1
bind r source-file ~/.tmux.conf
EOF

    run validate_tmux_syntax "$config_file"
    assert_success
}

@test "validate_tmux_syntax returns 1 for invalid tmux config" {
    local config_file="${PIMPMYTMUX_TEST_DIR}/invalid.conf"
    cat > "$config_file" << 'EOF'
# Invalid tmux configuration - unknown command
this_is_not_a_valid_command
EOF

    run validate_tmux_syntax "$config_file"
    assert_failure
}

@test "validate_tmux_syntax returns 1 for non-existent file" {
    run validate_tmux_syntax "/nonexistent/file.conf"
    assert_failure
}

@test "validate_tmux_syntax returns 1 for empty path" {
    run validate_tmux_syntax ""
    assert_failure
}

# -----------------------------------------------------------------------------
# get_validation_errors tests
# -----------------------------------------------------------------------------

@test "get_validation_errors returns empty for valid config" {
    local config_file="${PIMPMYTMUX_TEST_DIR}/valid.conf"
    cat > "$config_file" << 'EOF'
set -g prefix C-a
set -g mouse on
EOF

    run get_validation_errors "$config_file"
    assert_success
    [[ -z "$output" ]] || [[ "$output" == "" ]]
}

@test "get_validation_errors returns error message for invalid config" {
    local config_file="${PIMPMYTMUX_TEST_DIR}/invalid.conf"
    cat > "$config_file" << 'EOF'
# Invalid - unknown command
totally_invalid_command_xyz
EOF

    run get_validation_errors "$config_file"
    # Should have some output (the error)
    [[ -n "$output" ]]
}

# -----------------------------------------------------------------------------
# validate_config_file tests
# -----------------------------------------------------------------------------

@test "validate_config_file returns 0 for valid file with correct permissions" {
    local config_file="${PIMPMYTMUX_TEST_DIR}/config.conf"
    echo "set -g mouse on" > "$config_file"
    chmod 644 "$config_file"

    run validate_config_file "$config_file"
    assert_success
}

@test "validate_config_file returns 1 for non-readable file" {
    local config_file="${PIMPMYTMUX_TEST_DIR}/unreadable.conf"
    echo "set -g mouse on" > "$config_file"
    chmod 000 "$config_file"

    run validate_config_file "$config_file"
    assert_failure

    # Cleanup
    chmod 644 "$config_file"
}

@test "validate_config_file returns 1 for directory instead of file" {
    local config_dir="${PIMPMYTMUX_TEST_DIR}/config_dir"
    mkdir -p "$config_dir"

    run validate_config_file "$config_dir"
    assert_failure
}

# -----------------------------------------------------------------------------
# validate_before_apply tests
# -----------------------------------------------------------------------------

@test "validate_before_apply returns 0 for valid config" {
    local config_file="${PIMPMYTMUX_TEST_DIR}/apply.conf"
    cat > "$config_file" << 'EOF'
set -g prefix C-a
set -g mouse on
set -g base-index 1
EOF

    run validate_before_apply "$config_file"
    assert_success
}

@test "validate_before_apply returns 1 and shows error for invalid config" {
    local config_file="${PIMPMYTMUX_TEST_DIR}/invalid_apply.conf"
    cat > "$config_file" << 'EOF'
# Invalid - unknown command causes error
unknown_command_that_does_not_exist
EOF

    run validate_before_apply "$config_file"
    assert_failure
}

@test "validate_before_apply returns 1 for missing file" {
    run validate_before_apply "/nonexistent/path/config.conf"
    assert_failure
}

# -----------------------------------------------------------------------------
# is_valid_tmux_option tests
# -----------------------------------------------------------------------------

@test "is_valid_tmux_option returns 0 for known option" {
    run is_valid_tmux_option "mouse"
    assert_success
}

@test "is_valid_tmux_option returns 0 for prefix option" {
    run is_valid_tmux_option "prefix"
    assert_success
}

@test "is_valid_tmux_option returns 0 for base-index" {
    run is_valid_tmux_option "base-index"
    assert_success
}

# -----------------------------------------------------------------------------
# Integration tests
# -----------------------------------------------------------------------------

@test "validation workflow: create, validate, report" {
    local config_file="${PIMPMYTMUX_TEST_DIR}/workflow.conf"

    # Create valid config
    cat > "$config_file" << 'EOF'
# pimpmytmux generated config
set -g prefix C-a
set -g mouse on
set -g base-index 1
set -g pane-base-index 1
set -g renumber-windows on
set -g history-limit 50000
bind r source-file ~/.tmux.conf \; display "Reloaded!"
EOF

    # Should validate successfully
    run validate_config_file "$config_file"
    assert_success

    run validate_tmux_syntax "$config_file"
    assert_success

    run validate_before_apply "$config_file"
    assert_success
}

@test "validation catches unknown command error" {
    local config_file="${PIMPMYTMUX_TEST_DIR}/bad_command.conf"
    cat > "$config_file" << 'EOF'
# This is not a valid tmux command
foobar_invalid_command arg1 arg2
EOF

    run validate_tmux_syntax "$config_file"
    # This should fail because of unknown command
    assert_failure
}
