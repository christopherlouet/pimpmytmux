#!/usr/bin/env bats
# pimpmytmux - Tests for lib/plugins.sh

load 'test_helper'

setup() {
    mkdir -p "$PIMPMYTMUX_CONFIG_DIR"
    mkdir -p "$PIMPMYTMUX_DATA_DIR"
    mkdir -p "$PIMPMYTMUX_CACHE_DIR"

    # Create plugins directory
    export PIMPMYTMUX_PLUGINS_DIR="$PIMPMYTMUX_DATA_DIR/plugins"
    mkdir -p "$PIMPMYTMUX_PLUGINS_DIR"

    # Load libraries
    load_lib 'core'
    load_lib 'plugins'
}

teardown() {
    cd /tmp
}

# -----------------------------------------------------------------------------
# Plugin directory tests
# -----------------------------------------------------------------------------

@test "get_plugins_dir returns correct path" {
    run get_plugins_dir
    assert_success
    assert_output_contains "plugins"
}

@test "init_plugins_dir creates plugins directory" {
    local plugins_dir
    plugins_dir=$(get_plugins_dir)
    rm -rf "$plugins_dir"

    run init_plugins_dir
    assert_success
    [[ -d "$plugins_dir" ]]
}

# -----------------------------------------------------------------------------
# Plugin listing tests
# -----------------------------------------------------------------------------

@test "list_plugins returns empty for no plugins" {
    run list_plugins
    assert_success
    [[ -z "$output" ]] || assert_output ""
}

@test "list_plugins returns installed plugins" {
    local plugins_dir
    plugins_dir=$(get_plugins_dir)

    # Create fake plugin
    mkdir -p "$plugins_dir/test-plugin"
    cat > "$plugins_dir/test-plugin/plugin.yaml" << 'EOF'
name: test-plugin
version: "1.0.0"
description: Test plugin
EOF

    run list_plugins
    assert_success
    assert_output_contains "test-plugin"
}

@test "list_plugins shows multiple plugins" {
    local plugins_dir
    plugins_dir=$(get_plugins_dir)

    # Create multiple fake plugins
    for name in plugin-a plugin-b plugin-c; do
        mkdir -p "$plugins_dir/$name"
        echo "name: $name" > "$plugins_dir/$name/plugin.yaml"
    done

    run list_plugins
    assert_success
    assert_output_contains "plugin-a"
    assert_output_contains "plugin-b"
    assert_output_contains "plugin-c"
}

# -----------------------------------------------------------------------------
# Plugin info tests
# -----------------------------------------------------------------------------

@test "get_plugin_info returns plugin metadata" {
    local plugins_dir
    plugins_dir=$(get_plugins_dir)

    mkdir -p "$plugins_dir/info-test"
    cat > "$plugins_dir/info-test/plugin.yaml" << 'EOF'
name: info-test
version: "2.0.0"
description: Plugin for testing info
author: Test Author
EOF

    run get_plugin_info "info-test" "name"
    assert_success
    assert_output "info-test"

    run get_plugin_info "info-test" "version"
    assert_success
    assert_output "2.0.0"
}

@test "get_plugin_info returns empty for missing plugin" {
    run get_plugin_info "nonexistent" "name"
    assert_failure
}

@test "is_plugin_installed returns true for installed plugin" {
    local plugins_dir
    plugins_dir=$(get_plugins_dir)

    mkdir -p "$plugins_dir/installed-plugin"
    echo "name: installed-plugin" > "$plugins_dir/installed-plugin/plugin.yaml"

    run is_plugin_installed "installed-plugin"
    assert_success
}

@test "is_plugin_installed returns false for missing plugin" {
    run is_plugin_installed "not-installed"
    assert_failure
}

# -----------------------------------------------------------------------------
# Plugin validation tests
# -----------------------------------------------------------------------------

@test "validate_plugin_structure accepts valid plugin" {
    local plugins_dir
    plugins_dir=$(get_plugins_dir)

    mkdir -p "$plugins_dir/valid-plugin"
    cat > "$plugins_dir/valid-plugin/plugin.yaml" << 'EOF'
name: valid-plugin
version: "1.0.0"
description: A valid plugin
EOF

    run validate_plugin_structure "$plugins_dir/valid-plugin"
    assert_success
}

@test "validate_plugin_structure rejects missing plugin.yaml" {
    local plugins_dir
    plugins_dir=$(get_plugins_dir)

    mkdir -p "$plugins_dir/invalid-plugin"
    # No plugin.yaml

    run validate_plugin_structure "$plugins_dir/invalid-plugin"
    assert_failure
}

@test "validate_plugin_structure rejects missing name" {
    local plugins_dir
    plugins_dir=$(get_plugins_dir)

    mkdir -p "$plugins_dir/no-name-plugin"
    cat > "$plugins_dir/no-name-plugin/plugin.yaml" << 'EOF'
version: "1.0.0"
description: Plugin without name
EOF

    run validate_plugin_structure "$plugins_dir/no-name-plugin"
    assert_failure
}

# -----------------------------------------------------------------------------
# Plugin installation tests
# -----------------------------------------------------------------------------

@test "extract_plugin_name_from_url extracts name from github URL" {
    run extract_plugin_name_from_url "https://github.com/user/pimpmytmux-awesome"
    assert_success
    assert_output "pimpmytmux-awesome"
}

@test "extract_plugin_name_from_url extracts name from git URL" {
    run extract_plugin_name_from_url "git@github.com:user/my-plugin.git"
    assert_success
    assert_output "my-plugin"
}

@test "extract_plugin_name_from_url handles .git suffix" {
    run extract_plugin_name_from_url "https://github.com/user/plugin-name.git"
    assert_success
    assert_output "plugin-name"
}

# Note: Actual git clone tests would require mocking or integration tests
@test "install_plugin fails for invalid URL" {
    run install_plugin ""
    assert_failure
    assert_output_contains "URL required"
}

@test "install_plugin fails for already installed plugin" {
    local plugins_dir
    plugins_dir=$(get_plugins_dir)

    # Pre-install plugin
    mkdir -p "$plugins_dir/existing-plugin"
    echo "name: existing-plugin" > "$plugins_dir/existing-plugin/plugin.yaml"

    run install_plugin "https://github.com/user/existing-plugin" "--skip-clone"
    assert_failure
    assert_output_contains "already installed"
}

# -----------------------------------------------------------------------------
# Plugin removal tests
# -----------------------------------------------------------------------------

@test "remove_plugin removes installed plugin" {
    local plugins_dir
    plugins_dir=$(get_plugins_dir)

    mkdir -p "$plugins_dir/to-remove"
    echo "name: to-remove" > "$plugins_dir/to-remove/plugin.yaml"

    run remove_plugin "to-remove"
    assert_success
    [[ ! -d "$plugins_dir/to-remove" ]]
}

@test "remove_plugin fails for non-installed plugin" {
    run remove_plugin "not-installed"
    assert_failure
    assert_output_contains "not installed"
}

# -----------------------------------------------------------------------------
# Plugin hooks tests
# -----------------------------------------------------------------------------

@test "run_plugin_hook executes on_install hook" {
    local plugins_dir
    plugins_dir=$(get_plugins_dir)

    mkdir -p "$plugins_dir/hook-test"
    cat > "$plugins_dir/hook-test/plugin.yaml" << 'EOF'
name: hook-test
version: "1.0.0"
EOF

    # Create on_install hook
    cat > "$plugins_dir/hook-test/on_install.sh" << 'EOF'
#!/usr/bin/env bash
echo "Install hook executed"
EOF
    chmod +x "$plugins_dir/hook-test/on_install.sh"

    run run_plugin_hook "hook-test" "on_install"
    assert_success
    assert_output_contains "Install hook executed"
}

@test "run_plugin_hook skips missing hook silently" {
    local plugins_dir
    plugins_dir=$(get_plugins_dir)

    mkdir -p "$plugins_dir/no-hook"
    echo "name: no-hook" > "$plugins_dir/no-hook/plugin.yaml"

    run run_plugin_hook "no-hook" "on_apply"
    assert_success
}

# -----------------------------------------------------------------------------
# Plugin enable/disable tests
# -----------------------------------------------------------------------------

@test "enable_plugin marks plugin as enabled" {
    local plugins_dir
    plugins_dir=$(get_plugins_dir)

    mkdir -p "$plugins_dir/enable-test"
    echo "name: enable-test" > "$plugins_dir/enable-test/plugin.yaml"

    run enable_plugin "enable-test"
    assert_success

    run is_plugin_enabled "enable-test"
    assert_success
}

@test "disable_plugin marks plugin as disabled" {
    local plugins_dir
    plugins_dir=$(get_plugins_dir)

    mkdir -p "$plugins_dir/disable-test"
    echo "name: disable-test" > "$plugins_dir/disable-test/plugin.yaml"

    enable_plugin "disable-test"

    run disable_plugin "disable-test"
    assert_success

    run is_plugin_enabled "disable-test"
    assert_failure
}

@test "list_enabled_plugins returns only enabled plugins" {
    local plugins_dir
    plugins_dir=$(get_plugins_dir)

    # Create plugins
    for name in enabled-a enabled-b disabled-c; do
        mkdir -p "$plugins_dir/$name"
        echo "name: $name" > "$plugins_dir/$name/plugin.yaml"
    done

    enable_plugin "enabled-a"
    enable_plugin "enabled-b"
    # disabled-c stays disabled

    run list_enabled_plugins
    assert_success
    assert_output_contains "enabled-a"
    assert_output_contains "enabled-b"
    refute_output_contains "disabled-c"
}
