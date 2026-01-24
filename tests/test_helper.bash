#!/usr/bin/env bash
# pimpmytmux - Test helper for bats

# Get the project root directory
export PIMPMYTMUX_ROOT="${BATS_TEST_DIRNAME}/.."
export PIMPMYTMUX_LIB_DIR="${PIMPMYTMUX_ROOT}/lib"

# Create temp directories for tests
export PIMPMYTMUX_TEST_DIR="${BATS_TMPDIR}/pimpmytmux-test-$$"
export PIMPMYTMUX_CONFIG_DIR="${PIMPMYTMUX_TEST_DIR}/config"
export PIMPMYTMUX_DATA_DIR="${PIMPMYTMUX_TEST_DIR}/data"
export PIMPMYTMUX_CACHE_DIR="${PIMPMYTMUX_TEST_DIR}/cache"

# Disable colors in tests
export NO_COLOR=1
export PIMPMYTMUX_VERBOSITY=0

# Setup function - runs before each test
setup() {
    mkdir -p "$PIMPMYTMUX_CONFIG_DIR"
    mkdir -p "$PIMPMYTMUX_DATA_DIR"
    mkdir -p "$PIMPMYTMUX_CACHE_DIR"
}

# Teardown function - runs after each test
teardown() {
    rm -rf "$PIMPMYTMUX_TEST_DIR"
}

# Load a library file
load_lib() {
    local lib_name="$1"
    source "${PIMPMYTMUX_LIB_DIR}/${lib_name}.sh"
}

# Assert that a command succeeds
assert_success() {
    if [[ "$status" -ne 0 ]]; then
        echo "Expected success but got status $status"
        echo "Output: $output"
        return 1
    fi
}

# Assert that a command fails
assert_failure() {
    if [[ "$status" -eq 0 ]]; then
        echo "Expected failure but got success"
        echo "Output: $output"
        return 1
    fi
}

# Assert output contains a string
assert_output_contains() {
    local expected="$1"
    if [[ "$output" != *"$expected"* ]]; then
        echo "Expected output to contain: $expected"
        echo "Actual output: $output"
        return 1
    fi
}

# Assert output equals a string
assert_output_equals() {
    local expected="$1"
    if [[ "$output" != "$expected" ]]; then
        echo "Expected output: $expected"
        echo "Actual output: $output"
        return 1
    fi
}

# Alias for assert_output_equals
assert_output() {
    assert_output_equals "$1"
}

# Assert output does NOT contain a string
refute_output_contains() {
    local unexpected="$1"
    if [[ "$output" == *"$unexpected"* ]]; then
        echo "Expected output NOT to contain: $unexpected"
        echo "Actual output: $output"
        return 1
    fi
}

# Assert a file exists
assert_file_exists() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "Expected file to exist: $file"
        return 1
    fi
}

# Assert a directory exists
assert_dir_exists() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        echo "Expected directory to exist: $dir"
        return 1
    fi
}

# Create a test YAML config
create_test_config() {
    local content="${1:-}"
    local config_file="${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml"

    if [[ -z "$content" ]]; then
        content='
theme: cyberpunk

general:
  prefix: C-a
  mouse: true
  base_index: 1

modules:
  sessions:
    enabled: true
  navigation:
    enabled: true
    vim_mode: true
'
    fi

    echo "$content" > "$config_file"
    echo "$config_file"
}
