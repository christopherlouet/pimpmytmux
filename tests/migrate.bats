#!/usr/bin/env bats
# pimpmytmux - Tests for lib/migrate.sh

load 'test_helper'

setup() {
    mkdir -p "$PIMPMYTMUX_CONFIG_DIR"
    mkdir -p "$PIMPMYTMUX_DATA_DIR"
    mkdir -p "$PIMPMYTMUX_CACHE_DIR"

    # Load libraries
    load_lib 'core'
    load_lib 'migrate'
}

teardown() {
    cd /tmp
}

# -----------------------------------------------------------------------------
# Version detection tests
# -----------------------------------------------------------------------------

@test "detect_config_version returns unknown for missing config" {
    rm -f "$PIMPMYTMUX_CONFIG_DIR/pimpmytmux.yaml"

    run detect_config_version
    assert_success
    assert_output "unknown"
}

@test "detect_config_version returns 0.1.0 for old format" {
    cat > "$PIMPMYTMUX_CONFIG_DIR/pimpmytmux.yaml" << 'EOF'
# Old format without version
theme: default
general:
  prefix: C-b
EOF

    run detect_config_version
    assert_success
    assert_output "0.1.0"
}

@test "detect_config_version returns version from config" {
    cat > "$PIMPMYTMUX_CONFIG_DIR/pimpmytmux.yaml" << 'EOF'
version: "1.0.0"
theme: default
EOF

    run detect_config_version
    assert_success
    assert_output "1.0.0"
}

# -----------------------------------------------------------------------------
# Version comparison tests
# -----------------------------------------------------------------------------

@test "compare_versions returns 0 for equal versions" {
    run compare_versions "1.0.0" "1.0.0"
    assert_success
    assert_output "0"
}

@test "compare_versions returns -1 when first is lower" {
    run compare_versions "0.5.0" "1.0.0"
    assert_success
    assert_output "-1"
}

@test "compare_versions returns 1 when first is higher" {
    run compare_versions "2.0.0" "1.0.0"
    assert_success
    assert_output "1"
}

@test "compare_versions handles minor versions" {
    run compare_versions "1.1.0" "1.0.0"
    assert_success
    assert_output "1"
}

@test "compare_versions handles patch versions" {
    run compare_versions "1.0.1" "1.0.0"
    assert_success
    assert_output "1"
}

# -----------------------------------------------------------------------------
# Migration requirement tests
# -----------------------------------------------------------------------------

@test "needs_migration returns true for old config" {
    cat > "$PIMPMYTMUX_CONFIG_DIR/pimpmytmux.yaml" << 'EOF'
theme: default
EOF

    run needs_migration
    assert_success
}

@test "needs_migration returns false for current config" {
    cat > "$PIMPMYTMUX_CONFIG_DIR/pimpmytmux.yaml" << 'EOF'
version: "1.0.0"
theme: default
EOF

    run needs_migration
    assert_failure
}

# -----------------------------------------------------------------------------
# Migration tests
# -----------------------------------------------------------------------------

@test "get_migration_steps returns steps for 0.1.0 to 1.0.0" {
    run get_migration_steps "0.1.0" "1.0.0"
    assert_success
    assert_output_contains "add_version_field"
}

@test "migrate_add_version_field adds version to config" {
    cat > "$PIMPMYTMUX_CONFIG_DIR/pimpmytmux.yaml" << 'EOF'
theme: default
general:
  prefix: C-b
EOF

    run migrate_add_version_field "$PIMPMYTMUX_CONFIG_DIR/pimpmytmux.yaml"
    assert_success

    # Check version was added
    grep -q "version:" "$PIMPMYTMUX_CONFIG_DIR/pimpmytmux.yaml"
}

@test "backup_before_migrate creates backup" {
    cat > "$PIMPMYTMUX_CONFIG_DIR/pimpmytmux.yaml" << 'EOF'
theme: default
EOF

    run backup_before_migrate
    assert_success
    assert_output_contains "backup"
}

@test "migrate_config upgrades config from 0.1.0" {
    cat > "$PIMPMYTMUX_CONFIG_DIR/pimpmytmux.yaml" << 'EOF'
theme: default
general:
  prefix: C-b
EOF

    run migrate_config
    assert_success

    # Check version was added
    grep -q "version:" "$PIMPMYTMUX_CONFIG_DIR/pimpmytmux.yaml"
}

@test "migrate_config is idempotent" {
    cat > "$PIMPMYTMUX_CONFIG_DIR/pimpmytmux.yaml" << 'EOF'
version: "1.0.0"
theme: default
EOF

    run migrate_config
    assert_success

    # Should still have version
    grep -q "version:" "$PIMPMYTMUX_CONFIG_DIR/pimpmytmux.yaml"
}

# -----------------------------------------------------------------------------
# Rollback tests
# -----------------------------------------------------------------------------

@test "rollback_migration restores backup" {
    cat > "$PIMPMYTMUX_CONFIG_DIR/pimpmytmux.yaml" << 'EOF'
theme: default
EOF

    # Create backup
    local backup_path
    backup_path=$(backup_before_migrate)

    # Modify config
    echo "modified: true" >> "$PIMPMYTMUX_CONFIG_DIR/pimpmytmux.yaml"

    # Rollback
    run rollback_migration "$backup_path"
    assert_success

    # Check original content restored
    ! grep -q "modified:" "$PIMPMYTMUX_CONFIG_DIR/pimpmytmux.yaml"
}
