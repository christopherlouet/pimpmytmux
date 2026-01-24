#!/usr/bin/env bats
# pimpmytmux - Tests for lib/detect.sh

load 'test_helper'

setup() {
    mkdir -p "$PIMPMYTMUX_CONFIG_DIR"
    mkdir -p "$PIMPMYTMUX_DATA_DIR"
    mkdir -p "$PIMPMYTMUX_CACHE_DIR"

    # Create test project directories
    export TEST_PROJECT_DIR="${PIMPMYTMUX_TEST_DIR}/projects"
    mkdir -p "$TEST_PROJECT_DIR"

    # Load libraries
    load_lib 'core'
    load_lib 'detect'
}

teardown() {
    :
}

# -----------------------------------------------------------------------------
# Project type detection tests
# -----------------------------------------------------------------------------

@test "detect_project_type returns 'node' for package.json" {
    local project_dir="$TEST_PROJECT_DIR/node-project"
    mkdir -p "$project_dir"
    echo '{"name": "test-app"}' > "$project_dir/package.json"

    run detect_project_type "$project_dir"
    assert_success
    assert_output "node"
}

@test "detect_project_type returns 'rust' for Cargo.toml" {
    local project_dir="$TEST_PROJECT_DIR/rust-project"
    mkdir -p "$project_dir"
    echo '[package]' > "$project_dir/Cargo.toml"

    run detect_project_type "$project_dir"
    assert_success
    assert_output "rust"
}

@test "detect_project_type returns 'go' for go.mod" {
    local project_dir="$TEST_PROJECT_DIR/go-project"
    mkdir -p "$project_dir"
    echo 'module example.com/test' > "$project_dir/go.mod"

    run detect_project_type "$project_dir"
    assert_success
    assert_output "go"
}

@test "detect_project_type returns 'python' for pyproject.toml" {
    local project_dir="$TEST_PROJECT_DIR/python-project"
    mkdir -p "$project_dir"
    echo '[project]' > "$project_dir/pyproject.toml"

    run detect_project_type "$project_dir"
    assert_success
    assert_output "python"
}

@test "detect_project_type returns 'python' for requirements.txt" {
    local project_dir="$TEST_PROJECT_DIR/python-req"
    mkdir -p "$project_dir"
    echo 'flask' > "$project_dir/requirements.txt"

    run detect_project_type "$project_dir"
    assert_success
    assert_output "python"
}

@test "detect_project_type returns 'unknown' for empty directory" {
    local project_dir="$TEST_PROJECT_DIR/empty"
    mkdir -p "$project_dir"

    run detect_project_type "$project_dir"
    assert_success
    assert_output "unknown"
}

@test "detect_project_type uses current directory when no arg" {
    local project_dir="$TEST_PROJECT_DIR/node-cwd"
    mkdir -p "$project_dir"
    echo '{}' > "$project_dir/package.json"

    cd "$project_dir"
    run detect_project_type
    assert_success
    assert_output "node"
}

# -----------------------------------------------------------------------------
# Layout recommendation tests
# -----------------------------------------------------------------------------

@test "get_layout_for_project returns dev-fullstack for node" {
    run get_layout_for_project "node"
    assert_success
    assert_output "dev-fullstack"
}

@test "get_layout_for_project returns dev-api for rust" {
    run get_layout_for_project "rust"
    assert_success
    assert_output "dev-api"
}

@test "get_layout_for_project returns dev-api for go" {
    run get_layout_for_project "go"
    assert_success
    assert_output "dev-api"
}

@test "get_layout_for_project returns dev-fullstack for python" {
    run get_layout_for_project "python"
    assert_success
    assert_output "dev-fullstack"
}

@test "get_layout_for_project returns empty for unknown" {
    run get_layout_for_project "unknown"
    assert_success
    assert_output ""
}

# -----------------------------------------------------------------------------
# Project info tests
# -----------------------------------------------------------------------------

@test "get_project_name returns directory name" {
    local project_dir="$TEST_PROJECT_DIR/my-awesome-project"
    mkdir -p "$project_dir"

    run get_project_name "$project_dir"
    assert_success
    assert_output "my-awesome-project"
}

@test "get_project_name reads from package.json if available" {
    local project_dir="$TEST_PROJECT_DIR/named-project"
    mkdir -p "$project_dir"
    echo '{"name": "custom-name"}' > "$project_dir/package.json"

    run get_project_name "$project_dir"
    assert_success
    assert_output "custom-name"
}

@test "get_project_name reads from Cargo.toml if available" {
    local project_dir="$TEST_PROJECT_DIR/rust-named"
    mkdir -p "$project_dir"
    cat > "$project_dir/Cargo.toml" << 'EOF'
[package]
name = "rust-app"
EOF

    run get_project_name "$project_dir"
    assert_success
    assert_output "rust-app"
}

# -----------------------------------------------------------------------------
# Dev command detection tests
# -----------------------------------------------------------------------------

@test "get_dev_command returns npm run dev for node" {
    local project_dir="$TEST_PROJECT_DIR/node-dev"
    mkdir -p "$project_dir"
    cat > "$project_dir/package.json" << 'EOF'
{"scripts": {"dev": "vite"}}
EOF

    run get_dev_command "$project_dir"
    assert_success
    assert_output "npm run dev"
}

@test "get_dev_command returns npm start as fallback for node" {
    local project_dir="$TEST_PROJECT_DIR/node-start"
    mkdir -p "$project_dir"
    cat > "$project_dir/package.json" << 'EOF'
{"scripts": {"start": "node index.js"}}
EOF

    run get_dev_command "$project_dir"
    assert_success
    assert_output "npm start"
}

@test "get_dev_command returns cargo watch for rust" {
    local project_dir="$TEST_PROJECT_DIR/rust-dev"
    mkdir -p "$project_dir"
    echo '[package]' > "$project_dir/Cargo.toml"

    run get_dev_command "$project_dir"
    assert_success
    assert_output "cargo watch -x run"
}

@test "get_dev_command returns go run for go" {
    local project_dir="$TEST_PROJECT_DIR/go-dev"
    mkdir -p "$project_dir"
    echo 'module test' > "$project_dir/go.mod"

    run get_dev_command "$project_dir"
    assert_success
    assert_output "go run ."
}

# -----------------------------------------------------------------------------
# Utility tests
# -----------------------------------------------------------------------------

@test "is_project_root returns true for project directory" {
    local project_dir="$TEST_PROJECT_DIR/is-project"
    mkdir -p "$project_dir"
    echo '{}' > "$project_dir/package.json"

    run is_project_root "$project_dir"
    assert_success
}

@test "is_project_root returns false for non-project directory" {
    local project_dir="$TEST_PROJECT_DIR/not-project"
    mkdir -p "$project_dir"

    run is_project_root "$project_dir"
    assert_failure
}

@test "list_project_types shows all supported types" {
    run list_project_types
    assert_success
    assert_output_contains "node"
    assert_output_contains "rust"
    assert_output_contains "go"
    assert_output_contains "python"
}
