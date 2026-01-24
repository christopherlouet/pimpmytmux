#!/usr/bin/env bats
# pimpmytmux - Tests for conditional keybindings

load 'test_helper'

setup() {
    mkdir -p "$PIMPMYTMUX_CONFIG_DIR"
    mkdir -p "$PIMPMYTMUX_DATA_DIR"
    mkdir -p "$PIMPMYTMUX_CACHE_DIR"

    # Load libraries
    load_lib 'core'
    load_lib 'config'
    load_lib 'conditional'
}

teardown() {
    cd /tmp
}

# -----------------------------------------------------------------------------
# Condition evaluation tests
# -----------------------------------------------------------------------------

@test "evaluate_condition returns true for matching hostname" {
    local current_host
    current_host=$(hostname)

    run evaluate_condition "hostname:$current_host"
    assert_success
}

@test "evaluate_condition returns false for non-matching hostname" {
    run evaluate_condition "hostname:nonexistent-host-12345"
    assert_failure
}

@test "evaluate_condition returns true for hostname pattern with wildcard" {
    run evaluate_condition "hostname:*"
    assert_success
}

@test "evaluate_condition returns true for matching project type" {
    # Create a Node.js project marker
    mkdir -p "$PIMPMYTMUX_TEST_DIR/nodeproject"
    echo '{}' > "$PIMPMYTMUX_TEST_DIR/nodeproject/package.json"

    cd "$PIMPMYTMUX_TEST_DIR/nodeproject"
    run evaluate_condition "project:node"
    assert_success
}

@test "evaluate_condition returns false for non-matching project type" {
    mkdir -p "$PIMPMYTMUX_TEST_DIR/emptyproject"
    cd "$PIMPMYTMUX_TEST_DIR/emptyproject"

    run evaluate_condition "project:rust"
    assert_failure
}

@test "evaluate_condition returns true for matching env variable" {
    export TEST_PIMPMYTMUX_VAR="enabled"

    run evaluate_condition "env:TEST_PIMPMYTMUX_VAR=enabled"
    assert_success

    unset TEST_PIMPMYTMUX_VAR
}

@test "evaluate_condition returns false for non-matching env variable" {
    export TEST_PIMPMYTMUX_VAR="disabled"

    run evaluate_condition "env:TEST_PIMPMYTMUX_VAR=enabled"
    assert_failure

    unset TEST_PIMPMYTMUX_VAR
}

@test "evaluate_condition returns true for env variable existence check" {
    export TEST_PIMPMYTMUX_EXISTS="yes"

    run evaluate_condition "env:TEST_PIMPMYTMUX_EXISTS"
    assert_success

    unset TEST_PIMPMYTMUX_EXISTS
}

@test "evaluate_condition returns false for non-existent env variable" {
    unset TEST_PIMPMYTMUX_NOTEXIST

    run evaluate_condition "env:TEST_PIMPMYTMUX_NOTEXIST"
    assert_failure
}

# -----------------------------------------------------------------------------
# Conditional keybindings parsing tests
# -----------------------------------------------------------------------------

@test "get_conditional_keybindings returns bindings for matching condition" {
    local config_file="$PIMPMYTMUX_CONFIG_DIR/test-conditional.yaml"
    cat > "$config_file" << 'EOF'
theme: default
keybindings:
  reload: r
  conditional:
    - condition: "hostname:*"
      bindings:
        custom_bind: "C-t"
EOF

    PIMPMYTMUX_CONFIG_FILE="$config_file"

    run get_conditional_keybindings "$config_file"
    assert_success
    assert_output_contains "custom_bind"
}

@test "get_conditional_keybindings ignores non-matching conditions" {
    local config_file="$PIMPMYTMUX_CONFIG_DIR/test-conditional2.yaml"
    cat > "$config_file" << 'EOF'
theme: default
keybindings:
  reload: r
  conditional:
    - condition: "hostname:impossible-hostname-12345"
      bindings:
        should_not_appear: "C-x"
EOF

    run get_conditional_keybindings "$config_file"
    assert_success
    refute_output_contains "should_not_appear"
}

@test "merge_keybindings combines base and conditional" {
    run merge_keybindings "reload=r" "custom=t"
    assert_success
    assert_output_contains "reload=r"
    assert_output_contains "custom=t"
}

# -----------------------------------------------------------------------------
# Hostname condition tests
# -----------------------------------------------------------------------------

@test "parse_hostname_condition extracts hostname" {
    run parse_hostname_condition "hostname:myserver"
    assert_success
    assert_output "myserver"
}

@test "match_hostname returns true for exact match" {
    local current
    current=$(hostname)

    run match_hostname "$current"
    assert_success
}

@test "match_hostname returns true for wildcard" {
    run match_hostname "*"
    assert_success
}

@test "match_hostname returns true for prefix wildcard" {
    local current
    current=$(hostname)
    local prefix="${current:0:3}"

    run match_hostname "${prefix}*"
    assert_success
}

# -----------------------------------------------------------------------------
# Project condition tests
# -----------------------------------------------------------------------------

@test "parse_project_condition extracts project type" {
    run parse_project_condition "project:rust"
    assert_success
    assert_output "rust"
}

@test "match_project_type returns true for node project" {
    mkdir -p "$PIMPMYTMUX_TEST_DIR/nodetest"
    echo '{}' > "$PIMPMYTMUX_TEST_DIR/nodetest/package.json"
    cd "$PIMPMYTMUX_TEST_DIR/nodetest"

    run match_project_type "node"
    assert_success
}

@test "match_project_type returns true for rust project" {
    mkdir -p "$PIMPMYTMUX_TEST_DIR/rusttest"
    echo '[package]' > "$PIMPMYTMUX_TEST_DIR/rusttest/Cargo.toml"
    cd "$PIMPMYTMUX_TEST_DIR/rusttest"

    run match_project_type "rust"
    assert_success
}

@test "match_project_type returns true for go project" {
    mkdir -p "$PIMPMYTMUX_TEST_DIR/gotest"
    echo 'module test' > "$PIMPMYTMUX_TEST_DIR/gotest/go.mod"
    cd "$PIMPMYTMUX_TEST_DIR/gotest"

    run match_project_type "go"
    assert_success
}

@test "match_project_type returns false for wrong type" {
    mkdir -p "$PIMPMYTMUX_TEST_DIR/pythontest"
    echo 'name = "test"' > "$PIMPMYTMUX_TEST_DIR/pythontest/pyproject.toml"
    cd "$PIMPMYTMUX_TEST_DIR/pythontest"

    run match_project_type "rust"
    assert_failure
}

# -----------------------------------------------------------------------------
# Generate conditional keybindings tests
# -----------------------------------------------------------------------------

@test "generate_conditional_keybindings outputs tmux bind commands" {
    local config_file="$PIMPMYTMUX_CONFIG_DIR/test-gen.yaml"
    cat > "$config_file" << 'EOF'
theme: default
keybindings:
  reload: r
  conditional:
    - condition: "hostname:*"
      bindings:
        test_bind: "C-g"
        test_action: "display-message 'test'"
EOF

    PIMPMYTMUX_CONFIG_FILE="$config_file"

    run generate_conditional_keybindings "$config_file"
    assert_success
    # Should contain bind command
    assert_output_contains "bind"
}

@test "generate_conditional_keybindings handles multiple conditions" {
    local current_host
    current_host=$(hostname)

    local config_file="$PIMPMYTMUX_CONFIG_DIR/test-multi.yaml"
    cat > "$config_file" << EOF
theme: default
keybindings:
  reload: r
  conditional:
    - condition: "hostname:$current_host"
      bindings:
        host_bind: "C-h"
    - condition: "hostname:*"
      bindings:
        all_bind: "C-a"
EOF

    run generate_conditional_keybindings "$config_file"
    assert_success
    assert_output_contains "host_bind"
    assert_output_contains "all_bind"
}

@test "apply_conditional_keybindings does nothing when not in tmux" {
    unset TMUX

    run apply_conditional_keybindings
    assert_success
}
