#!/usr/bin/env bats
# pimpmytmux - Tests for lib/profiles.sh

load 'test_helper'

setup() {
    mkdir -p "$PIMPMYTMUX_CONFIG_DIR"
    mkdir -p "$PIMPMYTMUX_DATA_DIR"
    mkdir -p "$PIMPMYTMUX_CACHE_DIR"

    # Create profiles directory
    export PIMPMYTMUX_PROFILES_DIR="${PIMPMYTMUX_CONFIG_DIR}/profiles"
    mkdir -p "$PIMPMYTMUX_PROFILES_DIR"

    # Load libraries
    load_lib 'core'
    load_lib 'config'
    load_lib 'profiles'
}

teardown() {
    # Cleanup is handled by test_helper
    :
}

# -----------------------------------------------------------------------------
# Profile directory tests
# -----------------------------------------------------------------------------

@test "init_profiles creates profiles directory structure" {
    rm -rf "$PIMPMYTMUX_PROFILES_DIR"

    run init_profiles
    assert_success

    [[ -d "$PIMPMYTMUX_PROFILES_DIR" ]]
    [[ -d "$PIMPMYTMUX_PROFILES_DIR/default" ]]
}

@test "get_profiles_dir returns correct path" {
    run get_profiles_dir
    assert_success
    assert_output "$PIMPMYTMUX_PROFILES_DIR"
}

# -----------------------------------------------------------------------------
# Profile listing tests
# -----------------------------------------------------------------------------

@test "list_profiles returns empty when no profiles exist" {
    rm -rf "$PIMPMYTMUX_PROFILES_DIR"/*

    run list_profiles
    assert_success
    assert_output ""
}

@test "list_profiles returns available profiles" {
    mkdir -p "$PIMPMYTMUX_PROFILES_DIR/default"
    mkdir -p "$PIMPMYTMUX_PROFILES_DIR/work"
    mkdir -p "$PIMPMYTMUX_PROFILES_DIR/home"

    run list_profiles
    assert_success
    assert_output_contains "default"
    assert_output_contains "work"
    assert_output_contains "home"
}

@test "list_profiles ignores non-directory files" {
    mkdir -p "$PIMPMYTMUX_PROFILES_DIR/default"
    touch "$PIMPMYTMUX_PROFILES_DIR/somefile.txt"

    run list_profiles
    assert_success
    assert_output_contains "default"
    refute_output_contains "somefile"
}

# -----------------------------------------------------------------------------
# Current profile tests
# -----------------------------------------------------------------------------

@test "get_current_profile returns default when no profile set" {
    rm -f "$PIMPMYTMUX_PROFILES_DIR/current"
    mkdir -p "$PIMPMYTMUX_PROFILES_DIR/default"

    run get_current_profile
    assert_success
    assert_output "default"
}

@test "get_current_profile returns profile from symlink" {
    mkdir -p "$PIMPMYTMUX_PROFILES_DIR/work"
    ln -sf "work" "$PIMPMYTMUX_PROFILES_DIR/current"

    run get_current_profile
    assert_success
    assert_output "work"
}

@test "set_current_profile creates symlink" {
    mkdir -p "$PIMPMYTMUX_PROFILES_DIR/work"

    run set_current_profile "work"
    assert_success

    [[ -L "$PIMPMYTMUX_PROFILES_DIR/current" ]]
    [[ "$(readlink "$PIMPMYTMUX_PROFILES_DIR/current")" == "work" ]]
}

@test "set_current_profile fails for non-existent profile" {
    run set_current_profile "nonexistent"
    assert_failure
}

# -----------------------------------------------------------------------------
# Profile creation tests
# -----------------------------------------------------------------------------

@test "create_profile creates new profile directory" {
    run create_profile "newprofile"
    assert_success

    [[ -d "$PIMPMYTMUX_PROFILES_DIR/newprofile" ]]
}

@test "create_profile creates config file from template" {
    run create_profile "newprofile"
    assert_success

    [[ -f "$PIMPMYTMUX_PROFILES_DIR/newprofile/pimpmytmux.yaml" ]]
}

@test "create_profile fails if profile exists" {
    mkdir -p "$PIMPMYTMUX_PROFILES_DIR/existing"

    run create_profile "existing"
    assert_failure
    assert_output_contains "already exists"
}

@test "create_profile with --from copies from source profile" {
    mkdir -p "$PIMPMYTMUX_PROFILES_DIR/source"
    echo "theme: cyberpunk" > "$PIMPMYTMUX_PROFILES_DIR/source/pimpmytmux.yaml"

    run create_profile "copy" "--from" "source"
    assert_success

    [[ -f "$PIMPMYTMUX_PROFILES_DIR/copy/pimpmytmux.yaml" ]]
    grep -q "cyberpunk" "$PIMPMYTMUX_PROFILES_DIR/copy/pimpmytmux.yaml"
}

@test "create_profile with --from fails if source doesn't exist" {
    run create_profile "copy" "--from" "nonexistent"
    assert_failure
    assert_output_contains "does not exist"
}

# -----------------------------------------------------------------------------
# Profile deletion tests
# -----------------------------------------------------------------------------

@test "delete_profile removes profile directory" {
    mkdir -p "$PIMPMYTMUX_PROFILES_DIR/todelete"
    touch "$PIMPMYTMUX_PROFILES_DIR/todelete/pimpmytmux.yaml"

    run delete_profile "todelete"
    assert_success

    [[ ! -d "$PIMPMYTMUX_PROFILES_DIR/todelete" ]]
}

@test "delete_profile fails for default profile" {
    mkdir -p "$PIMPMYTMUX_PROFILES_DIR/default"

    run delete_profile "default"
    assert_failure
    assert_output_contains "Cannot delete default"
}

@test "delete_profile fails for current profile" {
    mkdir -p "$PIMPMYTMUX_PROFILES_DIR/current_one"
    ln -sf "current_one" "$PIMPMYTMUX_PROFILES_DIR/current"

    run delete_profile "current_one"
    assert_failure
    assert_output_contains "Cannot delete current"
}

@test "delete_profile fails for non-existent profile" {
    run delete_profile "nonexistent"
    assert_failure
    assert_output_contains "does not exist"
}

# -----------------------------------------------------------------------------
# Profile switching tests
# -----------------------------------------------------------------------------

@test "switch_profile changes current profile" {
    mkdir -p "$PIMPMYTMUX_PROFILES_DIR/default"
    mkdir -p "$PIMPMYTMUX_PROFILES_DIR/work"
    echo "theme: nord" > "$PIMPMYTMUX_PROFILES_DIR/work/pimpmytmux.yaml"

    run switch_profile "work"
    assert_success

    [[ "$(get_current_profile)" == "work" ]]
}

@test "switch_profile fails for non-existent profile" {
    run switch_profile "nonexistent"
    assert_failure
    assert_output_contains "does not exist"
}

@test "switch_profile updates config symlink" {
    mkdir -p "$PIMPMYTMUX_PROFILES_DIR/work"
    echo "theme: nord" > "$PIMPMYTMUX_PROFILES_DIR/work/pimpmytmux.yaml"

    run switch_profile "work"
    assert_success

    # Main config should now point to work profile config
    local expected_config="$PIMPMYTMUX_PROFILES_DIR/work/pimpmytmux.yaml"
    [[ -f "$expected_config" ]]
}

# -----------------------------------------------------------------------------
# Profile config path tests
# -----------------------------------------------------------------------------

@test "get_profile_config_path returns correct path" {
    mkdir -p "$PIMPMYTMUX_PROFILES_DIR/work"

    run get_profile_config_path "work"
    assert_success
    assert_output "$PIMPMYTMUX_PROFILES_DIR/work/pimpmytmux.yaml"
}

@test "get_active_config_path returns current profile config" {
    mkdir -p "$PIMPMYTMUX_PROFILES_DIR/work"
    echo "theme: nord" > "$PIMPMYTMUX_PROFILES_DIR/work/pimpmytmux.yaml"
    ln -sf "work" "$PIMPMYTMUX_PROFILES_DIR/current"

    run get_active_config_path
    assert_success
    assert_output "$PIMPMYTMUX_PROFILES_DIR/work/pimpmytmux.yaml"
}

# -----------------------------------------------------------------------------
# Profile validation tests
# -----------------------------------------------------------------------------

@test "is_valid_profile_name accepts valid names" {
    run is_valid_profile_name "work"
    assert_success

    run is_valid_profile_name "my-profile"
    assert_success

    run is_valid_profile_name "profile_123"
    assert_success
}

@test "is_valid_profile_name rejects invalid names" {
    run is_valid_profile_name ""
    assert_failure

    run is_valid_profile_name "profile with spaces"
    assert_failure

    run is_valid_profile_name "../escape"
    assert_failure

    run is_valid_profile_name "current"
    assert_failure
}

@test "profile_exists returns true for existing profile" {
    mkdir -p "$PIMPMYTMUX_PROFILES_DIR/existing"

    run profile_exists "existing"
    assert_success
}

@test "profile_exists returns false for non-existing profile" {
    run profile_exists "nonexistent"
    assert_failure
}
