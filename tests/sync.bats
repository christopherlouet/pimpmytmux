#!/usr/bin/env bats
# pimpmytmux - Tests for lib/sync.sh

load 'test_helper'

setup() {
    mkdir -p "$PIMPMYTMUX_CONFIG_DIR"
    mkdir -p "$PIMPMYTMUX_DATA_DIR"
    mkdir -p "$PIMPMYTMUX_CACHE_DIR"

    # Create a fake git repo for testing
    export TEST_SYNC_REPO="${PIMPMYTMUX_TEST_DIR}/sync-repo"
    mkdir -p "$TEST_SYNC_REPO"
    cd "$TEST_SYNC_REPO"
    git init --quiet
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "initial" > README.md
    git add README.md
    git commit -m "initial" --quiet

    # Load libraries
    load_lib 'core'
    load_lib 'sync'
}

teardown() {
    cd /tmp
}

# -----------------------------------------------------------------------------
# Sync configuration tests
# -----------------------------------------------------------------------------

@test "get_sync_repo returns configured repo" {
    export PIMPMYTMUX_SYNC_REPO="git@github.com:user/dotfiles.git"

    run get_sync_repo
    assert_success
    assert_output "git@github.com:user/dotfiles.git"
}

@test "get_sync_repo returns empty when not configured" {
    unset PIMPMYTMUX_SYNC_REPO

    run get_sync_repo
    assert_success
    assert_output ""
}

@test "set_sync_repo saves repo URL" {
    local config_file="$PIMPMYTMUX_CONFIG_DIR/sync.conf"

    run set_sync_repo "git@github.com:user/config.git"
    assert_success

    [[ -f "$config_file" ]]
    grep -q "user/config.git" "$config_file"
}

@test "is_sync_configured returns true when repo set" {
    export PIMPMYTMUX_SYNC_REPO="git@github.com:user/dotfiles.git"

    run is_sync_configured
    assert_success
}

@test "is_sync_configured returns false when no repo" {
    unset PIMPMYTMUX_SYNC_REPO
    rm -f "$PIMPMYTMUX_CONFIG_DIR/sync.conf"

    run is_sync_configured
    assert_failure
}

# -----------------------------------------------------------------------------
# Sync directory tests
# -----------------------------------------------------------------------------

@test "get_sync_dir returns correct path" {
    run get_sync_dir
    assert_success
    assert_output_contains "pimpmytmux"
    assert_output_contains "sync"
}

@test "init_sync_dir creates sync directory" {
    local sync_dir
    sync_dir=$(get_sync_dir)
    rm -rf "$sync_dir"

    run init_sync_dir
    assert_success
    [[ -d "$sync_dir" ]]
}

# -----------------------------------------------------------------------------
# File tracking tests
# -----------------------------------------------------------------------------

@test "get_sync_files returns config files" {
    # Create some config files
    echo "theme: nord" > "$PIMPMYTMUX_CONFIG_DIR/pimpmytmux.yaml"
    mkdir -p "$PIMPMYTMUX_CONFIG_DIR/themes"
    echo "name: custom" > "$PIMPMYTMUX_CONFIG_DIR/themes/custom.yaml"

    run get_sync_files
    assert_success
    assert_output_contains "pimpmytmux.yaml"
}

@test "should_sync_file returns true for yaml files" {
    run should_sync_file "pimpmytmux.yaml"
    assert_success

    run should_sync_file "themes/custom.yaml"
    assert_success
}

@test "should_sync_file returns false for temp files" {
    run should_sync_file "pimpmytmux.yaml.bak"
    assert_failure

    run should_sync_file ".git/config"
    assert_failure
}

# -----------------------------------------------------------------------------
# Sync status tests
# -----------------------------------------------------------------------------

@test "get_sync_status returns clean for no changes" {
    # Setup a synced directory
    local sync_dir
    sync_dir=$(get_sync_dir)
    mkdir -p "$sync_dir"
    cd "$sync_dir"
    git init --quiet
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "test" > test.txt
    git add test.txt
    git commit -m "test" --quiet

    run get_sync_status
    assert_success
    assert_output_contains "clean"
}

@test "has_local_changes returns false for clean repo" {
    local sync_dir
    sync_dir=$(get_sync_dir)
    mkdir -p "$sync_dir"
    cd "$sync_dir"
    git init --quiet
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "test" > test.txt
    git add test.txt
    git commit -m "test" --quiet

    run has_local_changes
    assert_failure
}

@test "has_local_changes returns true for modified files" {
    local sync_dir
    sync_dir=$(get_sync_dir)
    mkdir -p "$sync_dir"
    cd "$sync_dir"
    git init --quiet
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "test" > test.txt
    git add test.txt
    git commit -m "test" --quiet
    echo "modified" > test.txt

    run has_local_changes
    assert_success
}
