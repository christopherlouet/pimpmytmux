#!/usr/bin/env bats
# pimpmytmux - Tests for Claude Code layouts and monitoring module

load 'test_helper'

setup() {
    mkdir -p "$PIMPMYTMUX_CONFIG_DIR"
    mkdir -p "$PIMPMYTMUX_DATA_DIR"
    mkdir -p "$PIMPMYTMUX_CACHE_DIR"

    # Load required libraries
    load_lib 'core'
}

# =============================================================================
# Module: claude-status.sh
# =============================================================================

# -----------------------------------------------------------------------------
# get_claude_status tests
# -----------------------------------------------------------------------------

@test "get_claude_status returns empty when no claude process" {
    source "${PIMPMYTMUX_ROOT}/modules/monitoring/claude-status.sh"

    # Mock tmux to return a pane_pid
    function tmux() {
        if [[ "$1" == "display-message" ]]; then
            echo "99999"
        fi
    }
    export -f tmux

    # Mock pgrep to find nothing
    function pgrep() {
        return 1
    }
    export -f pgrep

    run get_claude_status
    assert_success
    [[ -z "$output" ]]
}

@test "get_claude_status returns CC when claude process found" {
    source "${PIMPMYTMUX_ROOT}/modules/monitoring/claude-status.sh"

    # Mock tmux to return a pane_pid
    function tmux() {
        if [[ "$1" == "display-message" ]]; then
            echo "12345"
        fi
    }
    export -f tmux

    # Mock pgrep to find claude process
    function pgrep() {
        echo "12346"
        return 0
    }
    export -f pgrep

    run get_claude_status
    assert_success
    assert_output "CC"
}

@test "get_claude_status uses ps fallback when pgrep unavailable" {
    source "${PIMPMYTMUX_ROOT}/modules/monitoring/claude-status.sh"

    # Mock tmux
    function tmux() {
        if [[ "$1" == "display-message" ]]; then
            echo "12345"
        fi
    }
    export -f tmux

    # Mock check_command to say pgrep is not available
    function check_command() {
        if [[ "$1" == "pgrep" ]]; then
            return 1
        fi
        return 0
    }
    export -f check_command

    # Mock ps to find claude process
    function ps() {
        echo "  PID  PPID COMMAND"
        echo "12346 12345 claude"
    }
    export -f ps

    run get_claude_status
    assert_success
    assert_output "CC"
}

@test "get_claude_status returns empty with ps fallback when no claude" {
    source "${PIMPMYTMUX_ROOT}/modules/monitoring/claude-status.sh"

    # Mock tmux
    function tmux() {
        if [[ "$1" == "display-message" ]]; then
            echo "12345"
        fi
    }
    export -f tmux

    # Mock check_command to say pgrep is not available
    function check_command() {
        if [[ "$1" == "pgrep" ]]; then
            return 1
        fi
        return 0
    }
    export -f check_command

    # Mock ps to find NO claude process
    function ps() {
        echo "  PID  PPID COMMAND"
        echo "12346 12345 bash"
    }
    export -f ps

    run get_claude_status
    assert_success
    [[ -z "$output" ]]
}

# -----------------------------------------------------------------------------
# format_claude_indicator tests
# -----------------------------------------------------------------------------

@test "format_claude_indicator formats active status with color" {
    source "${PIMPMYTMUX_ROOT}/modules/monitoring/claude-status.sh"

    run format_claude_indicator "CC"
    assert_success
    assert_output_contains "#[fg=green]"
    assert_output_contains "CC"
    assert_output_contains "#[default]"
}

@test "format_claude_indicator returns empty for empty input" {
    source "${PIMPMYTMUX_ROOT}/modules/monitoring/claude-status.sh"

    run format_claude_indicator ""
    assert_success
    [[ -z "$output" ]]
}

# -----------------------------------------------------------------------------
# get_claude_status_formatted (combined function) tests
# -----------------------------------------------------------------------------

@test "get_claude_status_formatted returns formatted output when active" {
    source "${PIMPMYTMUX_ROOT}/modules/monitoring/claude-status.sh"

    # Mock tmux
    function tmux() {
        if [[ "$1" == "display-message" ]]; then
            echo "12345"
        fi
    }
    export -f tmux

    # Mock pgrep to find claude
    function pgrep() {
        echo "12346"
        return 0
    }
    export -f pgrep

    run get_claude_status_formatted
    assert_success
    assert_output_contains "#[fg=green]"
    assert_output_contains "CC"
}

@test "get_claude_status_formatted returns empty when inactive" {
    source "${PIMPMYTMUX_ROOT}/modules/monitoring/claude-status.sh"

    # Mock tmux
    function tmux() {
        if [[ "$1" == "display-message" ]]; then
            echo "99999"
        fi
    }
    export -f tmux

    # Mock pgrep to find nothing
    function pgrep() {
        return 1
    }
    export -f pgrep

    run get_claude_status_formatted
    assert_success
    [[ -z "$output" ]]
}

# =============================================================================
# Layout functions: apply_layout_claude_code
# =============================================================================

@test "apply_layout_claude_code creates 60/40 split with right side 50/50" {
    source "${PIMPMYTMUX_ROOT}/lib/wizard.sh"
    source "${PIMPMYTMUX_ROOT}/modules/sessions/layouts.sh"

    local tmux_calls=()
    function tmux() {
        tmux_calls+=("$*")
    }
    export -f tmux

    apply_layout_claude_code "/tmp"

    # Verify horizontal split 60/40
    local found_h_split=false
    local found_v_split=false
    local found_select_pane_0=false
    for cmd in "${tmux_calls[@]}"; do
        [[ "$cmd" == *"split-window -h -p 40"* ]] && found_h_split=true
        [[ "$cmd" == *"split-window -v -p 50"* ]] && found_v_split=true
        [[ "$cmd" == *"select-pane -t 0"* ]] && found_select_pane_0=true
    done

    [[ "$found_h_split" == "true" ]]
    [[ "$found_v_split" == "true" ]]
    [[ "$found_select_pane_0" == "true" ]]
}

@test "apply_layout_claude_code sends git status to pane 2" {
    source "${PIMPMYTMUX_ROOT}/lib/wizard.sh"
    source "${PIMPMYTMUX_ROOT}/modules/sessions/layouts.sh"

    local tmux_calls=()
    function tmux() {
        tmux_calls+=("$*")
    }
    export -f tmux

    apply_layout_claude_code "/tmp"

    # Verify git status sent to last pane
    local found_git=false
    for cmd in "${tmux_calls[@]}"; do
        [[ "$cmd" == *"send-keys"*"git status"* ]] && found_git=true
    done

    [[ "$found_git" == "true" ]]
}

# =============================================================================
# Layout functions: apply_layout_claude_agent_teams
# =============================================================================

@test "apply_layout_claude_agent_teams creates 2x2 grid" {
    source "${PIMPMYTMUX_ROOT}/lib/wizard.sh"
    source "${PIMPMYTMUX_ROOT}/modules/sessions/layouts.sh"

    local tmux_calls=()
    function tmux() {
        tmux_calls+=("$*")
        if [[ "$1" == "display-message" ]]; then
            echo "%0"
        fi
    }
    export -f tmux

    apply_layout_claude_agent_teams "/tmp"

    # Count split-window calls (should be 3: one horizontal, two vertical)
    local h_splits=0
    local v_splits=0
    for cmd in "${tmux_calls[@]}"; do
        [[ "$cmd" == *"split-window -h"* ]] && h_splits=$((h_splits + 1))
        [[ "$cmd" == *"split-window -v"* ]] && v_splits=$((v_splits + 1))
    done

    [[ "$h_splits" -eq 1 ]]
    [[ "$v_splits" -eq 2 ]]
}

@test "apply_layout_claude_agent_teams focuses on lead pane" {
    source "${PIMPMYTMUX_ROOT}/lib/wizard.sh"
    source "${PIMPMYTMUX_ROOT}/modules/sessions/layouts.sh"

    local tmux_calls=()
    function tmux() {
        tmux_calls+=("$*")
        if [[ "$1" == "display-message" ]]; then
            echo "%0"
        fi
    }
    export -f tmux

    apply_layout_claude_agent_teams "/tmp"

    # Last select-pane should focus back to base pane
    local last_select=""
    for cmd in "${tmux_calls[@]}"; do
        [[ "$cmd" == *"select-pane"* ]] && last_select="$cmd"
    done

    [[ "$last_select" == *"%0"* ]]
}

# =============================================================================
# Layout functions: apply_layout_claude_worktrees
# =============================================================================

@test "apply_layout_claude_worktrees creates 2 columns with 65/35 splits" {
    source "${PIMPMYTMUX_ROOT}/lib/wizard.sh"
    source "${PIMPMYTMUX_ROOT}/modules/sessions/layouts.sh"

    local tmux_calls=()
    function tmux() {
        tmux_calls+=("$*")
        if [[ "$1" == "display-message" ]]; then
            echo "%0"
        fi
    }
    export -f tmux

    apply_layout_claude_worktrees "/tmp"

    # Verify horizontal split (2 columns)
    local found_h_split=false
    local v_35_count=0
    for cmd in "${tmux_calls[@]}"; do
        [[ "$cmd" == *"split-window -h"* ]] && found_h_split=true
        [[ "$cmd" == *"split-window -v -p 35"* ]] && v_35_count=$((v_35_count + 1))
    done

    [[ "$found_h_split" == "true" ]]
    [[ "$v_35_count" -eq 2 ]]
}

@test "apply_layout_claude_worktrees focuses on worktree-1 pane" {
    source "${PIMPMYTMUX_ROOT}/lib/wizard.sh"
    source "${PIMPMYTMUX_ROOT}/modules/sessions/layouts.sh"

    local tmux_calls=()
    function tmux() {
        tmux_calls+=("$*")
        if [[ "$1" == "display-message" ]]; then
            echo "%0"
        fi
    }
    export -f tmux

    apply_layout_claude_worktrees "/tmp"

    # Last select-pane should focus back to base pane (worktree-1)
    local last_select=""
    for cmd in "${tmux_calls[@]}"; do
        [[ "$cmd" == *"select-pane"* ]] && last_select="$cmd"
    done

    [[ "$last_select" == *"%0"* ]]
}

# =============================================================================
# Layout registration tests
# =============================================================================

@test "apply_layout dispatches claude-code layout" {
    source "${PIMPMYTMUX_ROOT}/lib/wizard.sh"
    source "${PIMPMYTMUX_ROOT}/modules/sessions/layouts.sh"

    local tmux_calls=()
    function tmux() {
        tmux_calls+=("$*")
    }
    export -f tmux

    apply_layout "claude-code" "/tmp"

    # Should have created splits (proving dispatch worked)
    local found_split=false
    for cmd in "${tmux_calls[@]}"; do
        [[ "$cmd" == *"split-window"* ]] && found_split=true
    done

    [[ "$found_split" == "true" ]]
}

@test "apply_layout dispatches claude-agent-teams layout" {
    source "${PIMPMYTMUX_ROOT}/lib/wizard.sh"
    source "${PIMPMYTMUX_ROOT}/modules/sessions/layouts.sh"

    local tmux_calls=()
    function tmux() {
        tmux_calls+=("$*")
        if [[ "$1" == "display-message" ]]; then
            echo "%0"
        fi
    }
    export -f tmux

    apply_layout "claude-agent-teams" "/tmp"

    local found_split=false
    for cmd in "${tmux_calls[@]}"; do
        [[ "$cmd" == *"split-window"* ]] && found_split=true
    done

    [[ "$found_split" == "true" ]]
}

@test "apply_layout dispatches claude-worktrees layout" {
    source "${PIMPMYTMUX_ROOT}/lib/wizard.sh"
    source "${PIMPMYTMUX_ROOT}/modules/sessions/layouts.sh"

    local tmux_calls=()
    function tmux() {
        tmux_calls+=("$*")
        if [[ "$1" == "display-message" ]]; then
            echo "%0"
        fi
    }
    export -f tmux

    apply_layout "claude-worktrees" "/tmp"

    local found_split=false
    for cmd in "${tmux_calls[@]}"; do
        [[ "$cmd" == *"split-window"* ]] && found_split=true
    done

    [[ "$found_split" == "true" ]]
}

# =============================================================================
# Status bar integration tests
# =============================================================================

@test "_generate_claude_status_script creates executable script" {
    load_lib 'config'
    source "${PIMPMYTMUX_ROOT}/lib/status.sh"

    local script_path
    script_path=$(_generate_claude_status_script)

    assert_file_exists "$script_path"
    [[ -x "$script_path" ]]
}

@test "_generate_claude_status_script sources claude-status module" {
    load_lib 'config'
    source "${PIMPMYTMUX_ROOT}/lib/status.sh"

    local script_path
    script_path=$(_generate_claude_status_script)

    # Verify script content sources the module
    local content
    content=$(cat "$script_path")

    [[ "$content" == *"claude-status.sh"* ]]
    [[ "$content" == *"get_claude_status_formatted"* ]]
}

@test "generate_status_bar_config includes claude widget when configured" {
    load_lib 'config'
    source "${PIMPMYTMUX_ROOT}/lib/status.sh"

    # Create config with claude in monitoring components
    create_test_config '
theme: cyberpunk
modules:
  monitoring:
    enabled: true
    components: "claude,cpu,memory"
  devtools:
    git_status: false
status_bar:
  position: bottom
  interval: 5
'

    # Mock tmux
    function tmux() { :; }
    export -f tmux

    run generate_status_bar_config
    assert_success
    assert_output_contains "claude"
}
