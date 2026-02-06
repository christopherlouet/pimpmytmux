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

@test "get_claude_status returns CC when 1 claude process found" {
    source "${PIMPMYTMUX_ROOT}/modules/monitoring/claude-status.sh"

    # Mock tmux list-panes to return 1 pane PID
    function tmux() {
        if [[ "$1" == "list-panes" ]]; then
            echo "12345"
        fi
    }
    export -f tmux

    # Mock pgrep to find claude process
    function pgrep() {
        return 0
    }
    export -f pgrep

    run get_claude_status
    assert_success
    assert_output "CC"
}

@test "get_claude_status uses ps fallback when pgrep unavailable" {
    source "${PIMPMYTMUX_ROOT}/modules/monitoring/claude-status.sh"

    # Mock tmux list-panes
    function tmux() {
        if [[ "$1" == "list-panes" ]]; then
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

    # Mock tmux list-panes
    function tmux() {
        if [[ "$1" == "list-panes" ]]; then
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

    # Mock tmux list-panes
    function tmux() {
        if [[ "$1" == "list-panes" ]]; then
            echo "12345"
        fi
    }
    export -f tmux

    # Mock pgrep to find claude
    function pgrep() {
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

    # Mock tmux list-panes
    function tmux() {
        if [[ "$1" == "list-panes" ]]; then
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

# -----------------------------------------------------------------------------
# Detection precision tests (P1 - false positive prevention)
# -----------------------------------------------------------------------------

@test "_claude_detect_pgrep uses exact process name match" {
    source "${PIMPMYTMUX_ROOT}/modules/monitoring/claude-status.sh"

    local pgrep_flags=""
    function pgrep() {
        pgrep_flags="$*"
        return 0
    }
    export -f pgrep

    _claude_detect_pgrep "12345"

    # Should use -x (exact name match) instead of -f (full cmdline match)
    [[ "$pgrep_flags" == *"-x"* ]]
}

@test "_claude_detect_ps rejects PID substring matches" {
    source "${PIMPMYTMUX_ROOT}/modules/monitoring/claude-status.sh"

    # Process has PPID 1234 but we search for parent 123
    function ps() {
        printf "%7d %7d %s\n" 5678 1234 "claude"
    }
    export -f ps

    # Should NOT match because parent PID is 1234, not 123
    run _claude_detect_ps "123"
    assert_failure
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

# =============================================================================
# Autostart helpers
# =============================================================================

@test "_claude_should_autostart returns false by default (opt-in)" {
    source "${PIMPMYTMUX_ROOT}/lib/wizard.sh"
    source "${PIMPMYTMUX_ROOT}/modules/sessions/layouts.sh"

    # No config file, no env var → default false
    run _claude_should_autostart
    assert_failure
}

@test "_claude_should_autostart returns true when YAML config enabled" {
    source "${PIMPMYTMUX_ROOT}/lib/wizard.sh"
    source "${PIMPMYTMUX_ROOT}/modules/sessions/layouts.sh"

    create_test_config '
modules:
  claude:
    autostart: true
'
    # Mock claude as available
    function claude() { :; }
    export -f claude

    run _claude_should_autostart
    assert_success
}

@test "_claude_should_autostart returns false when YAML config disabled" {
    source "${PIMPMYTMUX_ROOT}/lib/wizard.sh"
    source "${PIMPMYTMUX_ROOT}/modules/sessions/layouts.sh"

    create_test_config '
modules:
  claude:
    autostart: false
'

    run _claude_should_autostart
    assert_failure
}

@test "_claude_should_autostart env var overrides YAML config" {
    source "${PIMPMYTMUX_ROOT}/lib/wizard.sh"
    source "${PIMPMYTMUX_ROOT}/modules/sessions/layouts.sh"

    create_test_config '
modules:
  claude:
    autostart: false
'
    # Env var override
    export PIMPMYTMUX_CLAUDE_AUTOSTART=true

    # Mock claude as available
    function claude() { :; }
    export -f claude

    run _claude_should_autostart
    assert_success

    unset PIMPMYTMUX_CLAUDE_AUTOSTART
}

@test "_claude_should_autostart returns false when claude not in PATH" {
    source "${PIMPMYTMUX_ROOT}/lib/wizard.sh"
    source "${PIMPMYTMUX_ROOT}/modules/sessions/layouts.sh"

    create_test_config '
modules:
  claude:
    autostart: true
'

    # Ensure claude is NOT available (override any function)
    unset -f claude 2>/dev/null || true

    # Save and override PATH to exclude claude
    local orig_path="$PATH"
    export PATH="/usr/bin:/bin"

    run _claude_should_autostart

    export PATH="$orig_path"
    assert_failure
}

@test "_claude_launch_in_pane sends claude command via send-keys" {
    source "${PIMPMYTMUX_ROOT}/lib/wizard.sh"
    source "${PIMPMYTMUX_ROOT}/modules/sessions/layouts.sh"

    local tmux_calls=()
    function tmux() {
        tmux_calls+=("$*")
    }
    export -f tmux

    _claude_launch_in_pane "%0"

    local found_sendkeys=false
    for cmd in "${tmux_calls[@]}"; do
        [[ "$cmd" == *"send-keys"*"%0"*"claude"* ]] && found_sendkeys=true
    done

    [[ "$found_sendkeys" == "true" ]]
}

@test "_claude_launch_in_pane with agent_teams sends env var and flag" {
    source "${PIMPMYTMUX_ROOT}/lib/wizard.sh"
    source "${PIMPMYTMUX_ROOT}/modules/sessions/layouts.sh"

    local tmux_calls=()
    function tmux() {
        tmux_calls+=("$*")
    }
    export -f tmux

    _claude_launch_in_pane "%0" "true"

    local found_env=false
    local found_flag=false
    for cmd in "${tmux_calls[@]}"; do
        [[ "$cmd" == *"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1"* ]] && found_env=true
        [[ "$cmd" == *"--teammate-mode tmux"* ]] && found_flag=true
    done

    [[ "$found_env" == "true" ]]
    [[ "$found_flag" == "true" ]]
}

@test "_claude_launch_in_pane uses custom command from YAML config" {
    source "${PIMPMYTMUX_ROOT}/lib/wizard.sh"
    source "${PIMPMYTMUX_ROOT}/modules/sessions/layouts.sh"

    create_test_config '
modules:
  claude:
    command: "claude --model sonnet"
'

    local tmux_calls=()
    function tmux() {
        tmux_calls+=("$*")
    }
    export -f tmux

    _claude_launch_in_pane "%0"

    local found_custom=false
    for cmd in "${tmux_calls[@]}"; do
        [[ "$cmd" == *"claude --model sonnet"* ]] && found_custom=true
    done

    [[ "$found_custom" == "true" ]]
}

@test "_claude_launch_in_pane agent_teams appends flags to custom command" {
    source "${PIMPMYTMUX_ROOT}/lib/wizard.sh"
    source "${PIMPMYTMUX_ROOT}/modules/sessions/layouts.sh"

    create_test_config '
modules:
  claude:
    command: "claude --profile dev"
'

    local tmux_calls=()
    function tmux() {
        tmux_calls+=("$*")
    }
    export -f tmux

    _claude_launch_in_pane "%0" "true"

    local found_env=false
    local found_custom_flag=false
    for cmd in "${tmux_calls[@]}"; do
        [[ "$cmd" == *"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1"* ]] && found_env=true
        [[ "$cmd" == *"claude --profile dev --teammate-mode tmux"* ]] && found_custom_flag=true
    done

    [[ "$found_env" == "true" ]]
    [[ "$found_custom_flag" == "true" ]]
}

# =============================================================================
# Autostart integration in layouts
# =============================================================================

@test "apply_layout_claude_agent_teams launches claude with Agent Teams when autostart enabled" {
    source "${PIMPMYTMUX_ROOT}/lib/wizard.sh"
    source "${PIMPMYTMUX_ROOT}/modules/sessions/layouts.sh"

    create_test_config '
modules:
  claude:
    autostart: true
'
    # Mock claude as available
    function claude() { :; }
    export -f claude

    local tmux_calls=()
    function tmux() {
        tmux_calls+=("$*")
        if [[ "$1" == "display-message" ]]; then
            echo "%0"
        fi
    }
    export -f tmux

    apply_layout_claude_agent_teams "/tmp"

    local found_agent_teams=false
    for cmd in "${tmux_calls[@]}"; do
        [[ "$cmd" == *"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1"* ]] && found_agent_teams=true
    done

    [[ "$found_agent_teams" == "true" ]]
}

@test "apply_layout_claude_code launches claude standard when autostart enabled" {
    source "${PIMPMYTMUX_ROOT}/lib/wizard.sh"
    source "${PIMPMYTMUX_ROOT}/modules/sessions/layouts.sh"

    create_test_config '
modules:
  claude:
    autostart: true
'
    function claude() { :; }
    export -f claude

    local tmux_calls=()
    function tmux() {
        tmux_calls+=("$*")
    }
    export -f tmux

    apply_layout_claude_code "/tmp"

    # Should have send-keys with "claude" but NOT Agent Teams env var
    local found_claude_sendkeys=false
    local found_agent_teams=false
    for cmd in "${tmux_calls[@]}"; do
        [[ "$cmd" == *"send-keys"*"claude"* ]] && [[ "$cmd" != *"git"* ]] && found_claude_sendkeys=true
        [[ "$cmd" == *"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"* ]] && found_agent_teams=true
    done

    [[ "$found_claude_sendkeys" == "true" ]]
    [[ "$found_agent_teams" == "false" ]]
}

@test "apply_layout_claude_worktrees launches claude in both worktree panes when autostart enabled" {
    source "${PIMPMYTMUX_ROOT}/lib/wizard.sh"
    source "${PIMPMYTMUX_ROOT}/modules/sessions/layouts.sh"

    create_test_config '
modules:
  claude:
    autostart: true
'
    function claude() { :; }
    export -f claude

    local tmux_calls=()
    function tmux() {
        tmux_calls+=("$*")
        if [[ "$1" == "display-message" ]]; then
            echo "%0"
        fi
    }
    export -f tmux

    apply_layout_claude_worktrees "/tmp"

    # Count send-keys with "claude" (should be 2 - one per worktree)
    local claude_launches=0
    for cmd in "${tmux_calls[@]}"; do
        [[ "$cmd" == *"send-keys"*"claude"* ]] && claude_launches=$((claude_launches + 1))
    done

    [[ "$claude_launches" -eq 2 ]]
}

@test "apply_layout_claude_agent_teams does NOT launch claude when autostart disabled" {
    source "${PIMPMYTMUX_ROOT}/lib/wizard.sh"
    source "${PIMPMYTMUX_ROOT}/modules/sessions/layouts.sh"

    # No autostart config (default false)
    local tmux_calls=()
    function tmux() {
        tmux_calls+=("$*")
        if [[ "$1" == "display-message" ]]; then
            echo "%0"
        fi
    }
    export -f tmux

    apply_layout_claude_agent_teams "/tmp"

    # Should NOT have send-keys with "claude"
    local found_claude=false
    for cmd in "${tmux_calls[@]}"; do
        [[ "$cmd" == *"send-keys"*"claude"* ]] && found_claude=true
    done

    [[ "$found_claude" == "false" ]]
}

# =============================================================================
# Multi-agent monitoring (US3)
# =============================================================================

@test "_claude_count_window_agents returns 0 when no agents" {
    source "${PIMPMYTMUX_ROOT}/modules/monitoring/claude-status.sh"

    # Mock tmux list-panes returning 2 pane PIDs
    function tmux() {
        if [[ "$1" == "list-panes" ]]; then
            printf "11111\n22222\n"
        fi
    }
    export -f tmux

    # Mock pgrep to find nothing
    function pgrep() { return 1; }
    export -f pgrep

    run _claude_count_window_agents
    assert_success
    assert_output "0"
}

@test "_claude_count_window_agents returns 3 when 3 agents active" {
    source "${PIMPMYTMUX_ROOT}/modules/monitoring/claude-status.sh"

    # Mock tmux list-panes returning 4 pane PIDs
    function tmux() {
        if [[ "$1" == "list-panes" ]]; then
            printf "11111\n22222\n33333\n44444\n"
        fi
    }
    export -f tmux

    # Mock pgrep: finds claude for first 3 panes, not 4th
    # _claude_detect_pgrep calls: pgrep -P "$pane_pid" -f "claude"
    function pgrep() {
        # $2 is the pane_pid (after -P flag)
        case "$2" in
            11111|22222|33333) return 0 ;;
            *) return 1 ;;
        esac
    }
    export -f pgrep

    run _claude_count_window_agents
    assert_success
    assert_output "3"
}

@test "get_claude_status returns CC for 1 agent" {
    source "${PIMPMYTMUX_ROOT}/modules/monitoring/claude-status.sh"

    # Override _claude_count_window_agents
    function _claude_count_window_agents() { echo "1"; }
    export -f _claude_count_window_agents

    run get_claude_status
    assert_success
    assert_output "CC"
}

@test "get_claude_status returns CC:3 for 3 agents" {
    source "${PIMPMYTMUX_ROOT}/modules/monitoring/claude-status.sh"

    function _claude_count_window_agents() { echo "3"; }
    export -f _claude_count_window_agents

    run get_claude_status
    assert_success
    assert_output "CC:3"
}

@test "get_claude_status returns empty for 0 agents" {
    source "${PIMPMYTMUX_ROOT}/modules/monitoring/claude-status.sh"

    function _claude_count_window_agents() { echo "0"; }
    export -f _claude_count_window_agents

    run get_claude_status
    assert_success
    [[ -z "$output" ]]
}

@test "format_claude_indicator formats CC:3 with color" {
    source "${PIMPMYTMUX_ROOT}/modules/monitoring/claude-status.sh"

    run format_claude_indicator "CC:3"
    assert_success
    assert_output_contains "#[fg=green]"
    assert_output_contains "CC:3"
    assert_output_contains "#[default]"
}

# =============================================================================
# Status bar integration tests
# =============================================================================

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
