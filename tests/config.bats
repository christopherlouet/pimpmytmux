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
# yq requirement tests
# -----------------------------------------------------------------------------

@test "require_yq succeeds when yq is installed" {
    # yq should be installed for tests to work
    run require_yq
    assert_success
}

@test "yq_get works with yq installed" {
    local config_file="${PIMPMYTMUX_TEST_DIR}/test.yaml"
    echo "theme: matrix" > "$config_file"

    result=$(yq_get "$config_file" ".theme")
    [[ "$result" == "matrix" ]]
}

# -----------------------------------------------------------------------------
# Additional config value tests
# -----------------------------------------------------------------------------

@test "config_enabled returns true for yes value" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config '
modules:
  sessions:
    enabled: yes
'
    export PIMPMYTMUX_CONFIG_FILE="${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml"

    run config_enabled ".modules.sessions.enabled"
    assert_success
}

@test "config_enabled returns true for 1 value" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config '
modules:
  sessions:
    enabled: 1
'
    export PIMPMYTMUX_CONFIG_FILE="${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml"

    run config_enabled ".modules.sessions.enabled"
    assert_success
}

@test "get_config handles nested values" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config '
modules:
  navigation:
    vim_mode: true
    fzf_integration: false
'
    export PIMPMYTMUX_CONFIG_FILE="${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml"

    result=$(get_config ".modules.navigation.vim_mode" "false")
    [[ "$result" == "true" ]]

    result=$(get_config ".modules.navigation.fzf_integration" "true")
    [[ "$result" == "false" ]]
}

@test "yq_get handles nested paths" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    local config_file="${PIMPMYTMUX_TEST_DIR}/nested.yaml"
    cat > "$config_file" << 'EOF'
level1:
  level2:
    level3: deep_value
EOF

    result=$(yq_get "$config_file" ".level1.level2.level3")
    [[ "$result" == "deep_value" ]]
}

@test "yq_get returns empty for non-existent path" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    local config_file="${PIMPMYTMUX_TEST_DIR}/test.yaml"
    echo "theme: matrix" > "$config_file"

    result=$(yq_get "$config_file" ".nonexistent")
    [[ -z "$result" || "$result" == "" ]]
}

# -----------------------------------------------------------------------------
# Window settings generation tests
# -----------------------------------------------------------------------------

@test "generate_tmux_conf includes window renumber setting" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config '
windows:
  renumber: true
'
    local output_file="${PIMPMYTMUX_CONFIG_DIR}/tmux.conf"

    run generate_tmux_conf "${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml" "$output_file"
    assert_success

    grep -q "renumber-windows on" "$output_file"
}

@test "generate_tmux_conf includes auto rename setting" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config '
windows:
  auto_rename: false
'
    local output_file="${PIMPMYTMUX_CONFIG_DIR}/tmux.conf"

    run generate_tmux_conf "${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml" "$output_file"
    assert_success

    grep -q "automatic-rename off" "$output_file"
}

# -----------------------------------------------------------------------------
# Pane settings generation tests
# -----------------------------------------------------------------------------

@test "generate_tmux_conf includes pane display time" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config '
panes:
  display_time: 3000
'
    local output_file="${PIMPMYTMUX_CONFIG_DIR}/tmux.conf"

    run generate_tmux_conf "${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml" "$output_file"
    assert_success

    grep -q "display-panes-time 3000" "$output_file"
}

@test "generate_tmux_conf includes retain path bindings" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config '
panes:
  retain_path: true
'
    local output_file="${PIMPMYTMUX_CONFIG_DIR}/tmux.conf"

    run generate_tmux_conf "${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml" "$output_file"
    assert_success

    grep -q "pane_current_path" "$output_file"
}

# -----------------------------------------------------------------------------
# Status bar settings generation tests
# -----------------------------------------------------------------------------

@test "generate_tmux_conf includes status position" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config '
status_bar:
  position: top
'
    local output_file="${PIMPMYTMUX_CONFIG_DIR}/tmux.conf"

    run generate_tmux_conf "${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml" "$output_file"
    assert_success

    grep -q "status-position top" "$output_file"
}

@test "generate_tmux_conf includes status interval" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config '
status_bar:
  interval: 10
'
    local output_file="${PIMPMYTMUX_CONFIG_DIR}/tmux.conf"

    run generate_tmux_conf "${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml" "$output_file"
    assert_success

    grep -q "status-interval 10" "$output_file"
}

# -----------------------------------------------------------------------------
# General settings generation tests
# -----------------------------------------------------------------------------

@test "generate_tmux_conf includes base index" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config '
general:
  base_index: 0
'
    local output_file="${PIMPMYTMUX_CONFIG_DIR}/tmux.conf"

    run generate_tmux_conf "${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml" "$output_file"
    assert_success

    grep -q "base-index 0" "$output_file"
}

@test "generate_tmux_conf includes history limit" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config '
general:
  history_limit: 100000
'
    local output_file="${PIMPMYTMUX_CONFIG_DIR}/tmux.conf"

    run generate_tmux_conf "${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml" "$output_file"
    assert_success

    grep -q "history-limit 100000" "$output_file"
}

@test "generate_tmux_conf includes escape time" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config '
general:
  escape_time: 0
'
    local output_file="${PIMPMYTMUX_CONFIG_DIR}/tmux.conf"

    run generate_tmux_conf "${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml" "$output_file"
    assert_success

    grep -q "escape-time 0" "$output_file"
}

@test "generate_tmux_conf includes secondary prefix" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config '
general:
  prefix: C-b
  prefix2: C-a
'
    local output_file="${PIMPMYTMUX_CONFIG_DIR}/tmux.conf"

    run generate_tmux_conf "${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml" "$output_file"
    assert_success

    grep -q "prefix2 C-a" "$output_file"
}

# -----------------------------------------------------------------------------
# Keybinding generation tests
# -----------------------------------------------------------------------------

@test "generate_tmux_conf includes split keybindings" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config '
keybindings:
  split_horizontal: "|"
  split_vertical: "_"
'
    local output_file="${PIMPMYTMUX_CONFIG_DIR}/tmux.conf"

    run generate_tmux_conf "${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml" "$output_file"
    assert_success

    grep -q 'bind "|" split-window -h' "$output_file"
    grep -q 'bind "_" split-window -v' "$output_file"
}

@test "generate_tmux_conf includes copy mode vi keys when vim_mode enabled" {
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

    grep -q "mode-keys vi" "$output_file"
    grep -q "copy-mode-vi v" "$output_file"
    grep -q "copy-mode-vi y" "$output_file"
}

# -----------------------------------------------------------------------------
# Edge case tests
# -----------------------------------------------------------------------------

@test "generate_tmux_conf uses defaults for missing values" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    # Minimal config
    create_test_config 'theme: cyberpunk'
    local output_file="${PIMPMYTMUX_CONFIG_DIR}/tmux.conf"

    run generate_tmux_conf "${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml" "$output_file"
    assert_success

    # Should include defaults
    grep -q "prefix C-b" "$output_file"
    grep -q "mouse on" "$output_file"
    grep -q "history-limit 50000" "$output_file"
}

@test "validate_config warns for unusual prefix format" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi

    create_test_config '
general:
  prefix: unusual-prefix
'
    export PIMPMYTMUX_CONFIG_FILE="${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml"

    run validate_config "${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml"
    # Should succeed but may warn
    assert_success
}
