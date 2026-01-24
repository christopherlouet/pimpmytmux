#!/usr/bin/env bats
# pimpmytmux - Tests for lib/backup.sh

load 'test_helper'

setup() {
    mkdir -p "$PIMPMYTMUX_CONFIG_DIR"
    mkdir -p "$PIMPMYTMUX_DATA_DIR"
    mkdir -p "$PIMPMYTMUX_CACHE_DIR"

    # Load required libraries
    load_lib 'core'
    load_lib 'backup'
}

# -----------------------------------------------------------------------------
# backup_config tests
# -----------------------------------------------------------------------------

@test "backup_config creates backup of existing file" {
    local test_file="${PIMPMYTMUX_TEST_DIR}/test.conf"
    echo "test content" > "$test_file"

    run backup_config "$test_file"
    assert_success

    # Check backup was created in backups directory
    local backup_dir="${PIMPMYTMUX_DATA_DIR}/backups"
    [[ -d "$backup_dir" ]]
    local backup_count
    backup_count=$(ls -1 "$backup_dir" 2>/dev/null | wc -l)
    [[ "$backup_count" -ge 1 ]]
}

@test "backup_config returns backup path" {
    local test_file="${PIMPMYTMUX_TEST_DIR}/test.conf"
    echo "test content" > "$test_file"

    run backup_config "$test_file"
    assert_success

    # Output should be a path
    [[ -n "$output" ]]
    [[ -f "$output" ]]
}

@test "backup_config preserves file content" {
    local test_file="${PIMPMYTMUX_TEST_DIR}/test.conf"
    echo "original content 123" > "$test_file"

    backup_path=$(backup_config "$test_file")

    # Backup should have same content
    [[ "$(cat "$backup_path")" == "original content 123" ]]
}

@test "backup_config returns 0 for non-existent file" {
    run backup_config "/nonexistent/file.conf"
    assert_success
    # Should return empty (no backup created)
    [[ -z "$output" ]]
}

@test "backup_config creates backup with timestamp in name" {
    local test_file="${PIMPMYTMUX_TEST_DIR}/myconfig.conf"
    echo "test" > "$test_file"

    backup_path=$(backup_config "$test_file")

    # Backup name should contain timestamp pattern
    [[ "$backup_path" =~ [0-9]{8}_[0-9]{6} ]]
}

# -----------------------------------------------------------------------------
# restore_backup tests
# -----------------------------------------------------------------------------

@test "restore_backup restores from backup file" {
    local original_file="${PIMPMYTMUX_TEST_DIR}/original.conf"
    echo "original content" > "$original_file"

    # Create a backup
    local backup_path
    backup_path=$(backup_config "$original_file")

    # Modify original
    echo "modified content" > "$original_file"

    # Restore
    run restore_backup "$backup_path" "$original_file"
    assert_success

    # Should have original content
    [[ "$(cat "$original_file")" == "original content" ]]
}

@test "restore_backup fails for non-existent backup" {
    run restore_backup "/nonexistent/backup.bak" "${PIMPMYTMUX_TEST_DIR}/target.conf"
    assert_failure
}

@test "restore_backup creates target directory if needed" {
    local backup_file="${PIMPMYTMUX_TEST_DIR}/backup.conf"
    echo "backup content" > "$backup_file"

    local target="${PIMPMYTMUX_TEST_DIR}/subdir/restored.conf"

    run restore_backup "$backup_file" "$target"
    assert_success

    [[ -f "$target" ]]
    [[ "$(cat "$target")" == "backup content" ]]
}

# -----------------------------------------------------------------------------
# list_backups tests
# -----------------------------------------------------------------------------

@test "list_backups returns empty for no backups" {
    run list_backups
    assert_success
    # Could be empty or just header
}

@test "list_backups shows existing backups" {
    # Create some backup files
    local backup_dir="${PIMPMYTMUX_DATA_DIR}/backups"
    mkdir -p "$backup_dir"
    touch "${backup_dir}/test.conf.20260124_120000.bak"
    touch "${backup_dir}/test.conf.20260124_130000.bak"

    run list_backups
    assert_success

    # Should list the backups
    [[ "$output" =~ "20260124" ]]
}

@test "list_backups filters by filename when provided" {
    local backup_dir="${PIMPMYTMUX_DATA_DIR}/backups"
    mkdir -p "$backup_dir"
    touch "${backup_dir}/config1.conf.20260124_120000.bak"
    touch "${backup_dir}/config2.conf.20260124_130000.bak"

    run list_backups "config1"
    assert_success

    [[ "$output" =~ "config1" ]]
}

# -----------------------------------------------------------------------------
# cleanup_old_backups tests
# -----------------------------------------------------------------------------

@test "cleanup_old_backups keeps recent backups" {
    local backup_dir="${PIMPMYTMUX_DATA_DIR}/backups"
    mkdir -p "$backup_dir"

    # Create 3 backups
    touch "${backup_dir}/test.conf.20260124_120000.bak"
    touch "${backup_dir}/test.conf.20260124_130000.bak"
    touch "${backup_dir}/test.conf.20260124_140000.bak"

    # Keep last 5 (all should remain)
    run cleanup_old_backups 5
    assert_success

    local count
    count=$(ls -1 "$backup_dir" | wc -l)
    [[ "$count" -eq 3 ]]
}

@test "cleanup_old_backups removes old backups" {
    local backup_dir="${PIMPMYTMUX_DATA_DIR}/backups"
    mkdir -p "$backup_dir"

    # Create 5 backups with different timestamps
    touch -d "2026-01-20 12:00:00" "${backup_dir}/test.conf.20260120_120000.bak"
    touch -d "2026-01-21 12:00:00" "${backup_dir}/test.conf.20260121_120000.bak"
    touch -d "2026-01-22 12:00:00" "${backup_dir}/test.conf.20260122_120000.bak"
    touch -d "2026-01-23 12:00:00" "${backup_dir}/test.conf.20260123_120000.bak"
    touch -d "2026-01-24 12:00:00" "${backup_dir}/test.conf.20260124_120000.bak"

    # Keep only last 2
    run cleanup_old_backups 2
    assert_success

    local count
    count=$(ls -1 "$backup_dir" | wc -l)
    [[ "$count" -eq 2 ]]
}

@test "cleanup_old_backups handles empty backup directory" {
    local backup_dir="${PIMPMYTMUX_DATA_DIR}/backups"
    mkdir -p "$backup_dir"

    run cleanup_old_backups 5
    assert_success
}

# -----------------------------------------------------------------------------
# get_latest_backup tests
# -----------------------------------------------------------------------------

@test "get_latest_backup returns most recent backup" {
    local backup_dir="${PIMPMYTMUX_DATA_DIR}/backups"
    mkdir -p "$backup_dir"

    # Create backups with different timestamps
    touch -d "2026-01-20 12:00:00" "${backup_dir}/test.conf.20260120_120000.bak"
    touch -d "2026-01-24 14:00:00" "${backup_dir}/test.conf.20260124_140000.bak"
    touch -d "2026-01-22 12:00:00" "${backup_dir}/test.conf.20260122_120000.bak"

    run get_latest_backup "test.conf"
    assert_success

    # Should return the most recent (2026-01-24)
    [[ "$output" =~ "20260124_140000" ]]
}

@test "get_latest_backup returns empty when no backups exist" {
    run get_latest_backup "nonexistent.conf"
    assert_success
    [[ -z "$output" ]]
}

# -----------------------------------------------------------------------------
# Integration tests
# -----------------------------------------------------------------------------

@test "backup workflow: create, modify, restore" {
    local config_file="${PIMPMYTMUX_TEST_DIR}/workflow.conf"
    echo "version 1" > "$config_file"

    # Backup
    local backup_path
    backup_path=$(backup_config "$config_file")
    [[ -f "$backup_path" ]]

    # Modify
    echo "version 2" > "$config_file"
    [[ "$(cat "$config_file")" == "version 2" ]]

    # Restore
    restore_backup "$backup_path" "$config_file"
    [[ "$(cat "$config_file")" == "version 1" ]]
}

@test "multiple backups are created with unique names" {
    local config_file="${PIMPMYTMUX_TEST_DIR}/multi.conf"
    echo "content" > "$config_file"

    local backup1
    backup1=$(backup_config "$config_file")
    sleep 1  # Ensure different timestamp
    local backup2
    backup2=$(backup_config "$config_file")

    # Should be different files
    [[ "$backup1" != "$backup2" ]]
    [[ -f "$backup1" ]]
    [[ -f "$backup2" ]]
}
