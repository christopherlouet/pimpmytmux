#!/usr/bin/env bats
# pimpmytmux - Tests for modules/sessions/layouts.sh

load 'test_helper'

setup() {
    mkdir -p "$PIMPMYTMUX_CONFIG_DIR"
    mkdir -p "$PIMPMYTMUX_DATA_DIR"
    mkdir -p "$PIMPMYTMUX_CACHE_DIR"

    # Load required libraries
    load_lib 'core'

    # Source wizard for _wizard_confirm
    source "${PIMPMYTMUX_ROOT}/lib/wizard.sh"

    # Source layouts module
    source "${PIMPMYTMUX_ROOT}/modules/sessions/layouts.sh"
}

# -----------------------------------------------------------------------------
# _parse_layout_settings tests
# -----------------------------------------------------------------------------

@test "_parse_layout_settings extracts zen_mode setting" {
    local layout_file="${PIMPMYTMUX_ROOT}/templates/writing.yaml"

    _parse_layout_settings "$layout_file"

    [[ "$LAYOUT_ZEN_MODE" == "true" ]]
}

@test "_parse_layout_settings uses default when zen_mode missing" {
    # Create a minimal layout file without settings
    local temp_file="${PIMPMYTMUX_TEST_DIR}/minimal.yaml"
    cat > "$temp_file" << 'EOF'
name: Minimal
description: Test layout without settings

layout:
  orientation: horizontal
  panes:
    - size: 100%
EOF

    _parse_layout_settings "$temp_file"

    [[ "$LAYOUT_ZEN_MODE" == "false" ]]
}

# -----------------------------------------------------------------------------
# _confirm_layout_apply tests
# -----------------------------------------------------------------------------

@test "_confirm_layout_apply returns success with single pane" {
    # Mock tmux to return 1 pane
    function tmux() {
        if [[ "$1" == "display-message" ]]; then
            echo "1"
        fi
    }
    export -f tmux

    run _confirm_layout_apply "writing"
    assert_success
}

@test "_confirm_layout_apply prompts with multiple panes" {
    # Mock tmux to return 3 panes
    function tmux() {
        if [[ "$1" == "display-message" ]]; then
            echo "3"
        fi
    }
    export -f tmux

    # Mock _wizard_confirm to return false (user cancels)
    function _wizard_confirm() {
        echo "false"
    }
    export -f _wizard_confirm

    run _confirm_layout_apply "writing"
    assert_failure
}

@test "_confirm_layout_apply succeeds when user confirms" {
    # Mock tmux to return 3 panes
    function tmux() {
        if [[ "$1" == "display-message" ]]; then
            echo "3"
        fi
    }
    export -f tmux

    # Mock _wizard_confirm to return true (user confirms)
    function _wizard_confirm() {
        echo "true"
    }
    export -f _wizard_confirm

    run _confirm_layout_apply "writing"
    assert_success
}

# -----------------------------------------------------------------------------
# _apply_layout_settings tests
# -----------------------------------------------------------------------------

@test "_apply_layout_settings hides status bar and borders in zen mode" {
    LAYOUT_ZEN_MODE="true"

    local tmux_commands=()
    function tmux() {
        tmux_commands+=("$*")
    }
    export -f tmux

    _apply_layout_settings

    # Check that status off was called
    local found_status=false
    local found_border=false
    for cmd in "${tmux_commands[@]}"; do
        [[ "$cmd" == *"status off"* ]] && found_status=true
        [[ "$cmd" == *"pane-border-status off"* ]] && found_border=true
    done

    [[ "$found_status" == "true" ]]
    [[ "$found_border" == "true" ]]
}

@test "_apply_layout_settings restores status bar when zen_mode=false" {
    LAYOUT_ZEN_MODE="false"

    local tmux_commands=()
    function tmux() {
        tmux_commands+=("$*")
    }
    export -f tmux

    _apply_layout_settings

    # Check that status on was called (to restore status bar)
    local found=false
    for cmd in "${tmux_commands[@]}"; do
        if [[ "$cmd" == *"status on"* ]]; then
            found=true
            break
        fi
    done

    [[ "$found" == "true" ]]
}

# -----------------------------------------------------------------------------
# apply_layout_writing integration tests
# -----------------------------------------------------------------------------

@test "apply_layout_writing enables zen mode from YAML" {
    # Mock all tmux calls
    local tmux_calls=()
    function tmux() {
        tmux_calls+=("$*")
        if [[ "$1" == "display-message" ]]; then
            echo "1"  # Single pane, no confirmation needed
        fi
    }
    export -f tmux

    # Run the function
    apply_layout_writing "/tmp"

    # Verify zen mode was applied (status bar hidden)
    local zen_applied=false
    for cmd in "${tmux_calls[@]}"; do
        if [[ "$cmd" == *"status off"* ]]; then
            zen_applied=true
            break
        fi
    done

    [[ "$zen_applied" == "true" ]]
}

@test "apply_layout_writing respects user cancellation" {
    # Enable verbosity to see log messages
    export PIMPMYTMUX_VERBOSITY=1

    # Mock tmux with multiple panes
    function tmux() {
        if [[ "$1" == "display-message" ]]; then
            echo "3"
        fi
    }
    export -f tmux

    # Mock _wizard_confirm to return false
    function _wizard_confirm() {
        echo "false"
    }
    export -f _wizard_confirm

    run apply_layout_writing "/tmp"
    assert_failure

    # Output should contain warning about cancellation
    assert_output_contains "cancelled"
}

# -----------------------------------------------------------------------------
# apply_layout_from_file tests
# -----------------------------------------------------------------------------

@test "apply_layout_from_file applies zen mode settings" {
    # Mock tmux
    local tmux_calls=()
    function tmux() {
        tmux_calls+=("$*")
        if [[ "$1" == "display-message" ]]; then
            echo "1"
        fi
    }
    export -f tmux

    local layout_file="${PIMPMYTMUX_ROOT}/templates/writing.yaml"

    apply_layout_from_file "$layout_file" "/tmp"

    # Verify zen mode was applied (status bar hidden)
    local zen_applied=false
    for cmd in "${tmux_calls[@]}"; do
        if [[ "$cmd" == *"status off"* ]]; then
            zen_applied=true
            break
        fi
    done

    [[ "$zen_applied" == "true" ]]
}

@test "apply_layout_from_file returns error for missing file" {
    run apply_layout_from_file "/nonexistent/layout.yaml"
    assert_failure
    assert_output_contains "not found"
}

# -----------------------------------------------------------------------------
# zen_toggle tests
# -----------------------------------------------------------------------------

@test "zen_toggle on enables zen mode" {
    local tmux_calls=()
    function tmux() {
        tmux_calls+=("$*")
    }
    export -f tmux

    zen_toggle "on"

    local found_status_off=false
    for cmd in "${tmux_calls[@]}"; do
        [[ "$cmd" == *"status off"* ]] && found_status_off=true
    done

    [[ "$found_status_off" == "true" ]]
}

@test "zen_toggle off disables zen mode" {
    local tmux_calls=()
    function tmux() {
        tmux_calls+=("$*")
    }
    export -f tmux

    zen_toggle "off"

    local found_status_on=false
    for cmd in "${tmux_calls[@]}"; do
        [[ "$cmd" == *"status on"* ]] && found_status_on=true
    done

    [[ "$found_status_on" == "true" ]]
}

@test "zen_toggle without arg toggles based on current state" {
    # Mock tmux to return "on" status (normal mode)
    function tmux() {
        if [[ "$1" == "show" ]]; then
            echo "on"
        fi
    }
    export -f tmux

    # Should enable zen mode since current status is "on"
    run zen_toggle
    assert_success
}
