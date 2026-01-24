#!/usr/bin/env bats
# pimpmytmux - Tests for modules/sessions/templates.sh

load 'test_helper'

setup() {
    mkdir -p "$PIMPMYTMUX_CONFIG_DIR"
    mkdir -p "$PIMPMYTMUX_DATA_DIR"
    mkdir -p "$PIMPMYTMUX_CACHE_DIR"

    # Create templates directory
    export PIMPMYTMUX_SESSION_TEMPLATES_DIR="${PIMPMYTMUX_CONFIG_DIR}/session-templates"
    mkdir -p "$PIMPMYTMUX_SESSION_TEMPLATES_DIR"

    # Load libraries
    load_lib 'core'
    source "${PIMPMYTMUX_ROOT}/modules/sessions/templates.sh"
}

teardown() {
    :
}

# -----------------------------------------------------------------------------
# Template listing tests
# -----------------------------------------------------------------------------

@test "list_session_templates returns empty for no templates" {
    rm -rf "$PIMPMYTMUX_SESSION_TEMPLATES_DIR"/*

    run list_session_templates
    assert_success
    assert_output ""
}

@test "list_session_templates returns available templates" {
    echo 'name: dev' > "$PIMPMYTMUX_SESSION_TEMPLATES_DIR/dev.yaml"
    echo 'name: work' > "$PIMPMYTMUX_SESSION_TEMPLATES_DIR/work.yaml"

    run list_session_templates
    assert_success
    assert_output_contains "dev"
    assert_output_contains "work"
}

# -----------------------------------------------------------------------------
# Template loading tests
# -----------------------------------------------------------------------------

@test "load_session_template loads valid template" {
    cat > "$PIMPMYTMUX_SESSION_TEMPLATES_DIR/test.yaml" << 'EOF'
name: test-session
windows:
  - name: editor
    layout: main-vertical
EOF

    run load_session_template "test"
    assert_success
}

@test "load_session_template fails for missing template" {
    run load_session_template "nonexistent"
    assert_failure
    assert_output_contains "not found"
}

@test "get_template_name extracts name from template" {
    cat > "$PIMPMYTMUX_SESSION_TEMPLATES_DIR/mytemplate.yaml" << 'EOF'
name: my-custom-session
windows: []
EOF

    run get_template_name "mytemplate"
    assert_success
    assert_output "my-custom-session"
}

@test "get_template_name falls back to filename" {
    cat > "$PIMPMYTMUX_SESSION_TEMPLATES_DIR/noname.yaml" << 'EOF'
windows: []
EOF

    run get_template_name "noname"
    assert_success
    assert_output "noname"
}

# -----------------------------------------------------------------------------
# Variable substitution tests
# -----------------------------------------------------------------------------

@test "expand_template_vars replaces PROJECT_NAME" {
    export PROJECT_NAME="my-project"
    local template='Session: ${PROJECT_NAME}'

    run expand_template_vars "$template"
    assert_success
    assert_output "Session: my-project"
}

@test "expand_template_vars replaces PROJECT_ROOT" {
    export PROJECT_ROOT="/home/user/projects/app"
    local template='cd ${PROJECT_ROOT}'

    run expand_template_vars "$template"
    assert_success
    assert_output "cd /home/user/projects/app"
}

@test "expand_template_vars replaces EDITOR" {
    export EDITOR="nvim"
    local template='${EDITOR} .'

    run expand_template_vars "$template"
    assert_success
    assert_output "nvim ."
}

@test "expand_template_vars replaces multiple variables" {
    export PROJECT_NAME="test"
    export PROJECT_ROOT="/tmp/test"
    local template='cd ${PROJECT_ROOT} && echo ${PROJECT_NAME}'

    run expand_template_vars "$template"
    assert_success
    assert_output "cd /tmp/test && echo test"
}

@test "expand_template_vars leaves unknown vars unchanged" {
    local template='${UNKNOWN_VAR}'

    run expand_template_vars "$template"
    assert_success
    assert_output '${UNKNOWN_VAR}'
}

# -----------------------------------------------------------------------------
# Template window tests
# -----------------------------------------------------------------------------

@test "get_template_windows returns window count" {
    cat > "$PIMPMYTMUX_SESSION_TEMPLATES_DIR/multi.yaml" << 'EOF'
name: multi
windows:
  - name: editor
  - name: terminal
  - name: logs
EOF

    run get_template_window_count "multi"
    assert_success
    assert_output "3"
}

@test "get_template_window_name returns window name" {
    cat > "$PIMPMYTMUX_SESSION_TEMPLATES_DIR/named.yaml" << 'EOF'
name: named
windows:
  - name: first-window
  - name: second-window
EOF

    run get_template_window_name "named" 0
    assert_success
    assert_output "first-window"

    run get_template_window_name "named" 1
    assert_success
    assert_output "second-window"
}

# -----------------------------------------------------------------------------
# Template validation tests
# -----------------------------------------------------------------------------

@test "validate_session_template accepts valid template" {
    cat > "$PIMPMYTMUX_SESSION_TEMPLATES_DIR/valid.yaml" << 'EOF'
name: valid-session
windows:
  - name: main
    panes:
      - command: vim
EOF

    run validate_session_template "valid"
    assert_success
}

@test "validate_session_template rejects template without windows" {
    cat > "$PIMPMYTMUX_SESSION_TEMPLATES_DIR/invalid.yaml" << 'EOF'
name: invalid
EOF

    run validate_session_template "invalid"
    assert_failure
    assert_output_contains "windows"
}

@test "template_exists returns true for existing template" {
    echo 'name: test' > "$PIMPMYTMUX_SESSION_TEMPLATES_DIR/exists.yaml"

    run template_exists "exists"
    assert_success
}

@test "template_exists returns false for missing template" {
    run template_exists "missing"
    assert_failure
}
