#!/usr/bin/env bash
# pimpmytmux - Interactive Setup Wizard
# Guides users through initial configuration

# Guard against re-sourcing
[[ -n "${_PIMPMYTMUX_WIZARD_LOADED:-}" ]] && return 0
_PIMPMYTMUX_WIZARD_LOADED=1

# shellcheck source=lib/core.sh
source "${PIMPMYTMUX_LIB_DIR:-$(dirname "${BASH_SOURCE[0]}")}/core.sh"

# -----------------------------------------------------------------------------
# Wizard utilities
# -----------------------------------------------------------------------------

## Check if gum is available for fancy prompts
_use_gum() {
    check_command gum
}

## Display header/title
_wizard_header() {
    local title="$1"

    echo ""
    if _use_gum; then
        gum style \
            --foreground 212 \
            --border-foreground 212 \
            --border double \
            --align center \
            --width 50 \
            --margin "1 2" \
            --padding "1 2" \
            "$title"
    else
        echo "╔════════════════════════════════════════════════════╗"
        printf "║ %-50s ║\n" "$title"
        echo "╚════════════════════════════════════════════════════╝"
        echo ""
    fi
}

## Display step indicator
_wizard_step() {
    local current="$1"
    local total="$2"
    local description="$3"

    if _use_gum; then
        gum style --foreground 39 "Step $current/$total: $description"
    else
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  Step $current/$total: $description"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    fi
    echo ""
}

## Prompt for single choice
_wizard_choose() {
    local prompt="$1"
    shift
    local options=("$@")

    if _use_gum; then
        gum choose --header "$prompt" "${options[@]}"
    else
        echo "$prompt"
        local i=1
        for opt in "${options[@]}"; do
            echo "  $i) $opt"
            ((i++))
        done
        echo ""
        read -rp "Enter choice (1-${#options[@]}): " choice
        echo "${options[$((choice-1))]}"
    fi
}

## Prompt for multiple choices
_wizard_choose_multi() {
    local prompt="$1"
    shift
    local options=("$@")

    if _use_gum; then
        gum choose --no-limit --header "$prompt" "${options[@]}"
    else
        echo "$prompt"
        echo "(Enter numbers separated by spaces, or 'all' for all options)"
        local i=1
        for opt in "${options[@]}"; do
            echo "  $i) $opt"
            ((i++))
        done
        echo ""
        read -rp "Enter choices: " choices

        if [[ "$choices" == "all" ]]; then
            printf '%s\n' "${options[@]}"
        else
            for num in $choices; do
                echo "${options[$((num-1))]}"
            done
        fi
    fi
}

## Prompt for yes/no confirmation
_wizard_confirm() {
    local prompt="$1"
    local default="${2:-true}"

    if _use_gum; then
        if gum confirm "$prompt"; then
            echo "true"
        else
            echo "false"
        fi
    else
        local yn="[Y/n]"
        [[ "$default" == "false" ]] && yn="[y/N]"

        read -rp "$prompt $yn " answer

        case "${answer,,}" in
            y|yes) echo "true" ;;
            n|no) echo "false" ;;
            *) echo "$default" ;;
        esac
    fi
}

## Prompt for text input
_wizard_input() {
    local prompt="$1"
    local default="${2:-}"
    local placeholder="${3:-}"

    if _use_gum; then
        gum input --placeholder "$placeholder" --value "$default" --header "$prompt"
    else
        read -rp "$prompt [$default]: " answer
        echo "${answer:-$default}"
    fi
}

## Display spinner during operation
_wizard_spin() {
    local title="$1"
    shift

    if _use_gum; then
        gum spin --spinner dot --title "$title" -- "$@"
    else
        echo "$title..."
        "$@"
    fi
}

## Display preview box
_wizard_preview() {
    local title="$1"
    local content="$2"

    if _use_gum; then
        gum style \
            --border rounded \
            --border-foreground 240 \
            --padding "1 2" \
            --margin "1 0" \
            "$title" "" "$content"
    else
        echo "┌─ $title ─────────────────────────────────────────────┐"
        echo "$content" | while IFS= read -r line; do
            printf "│ %-52s │\n" "$line"
        done
        echo "└────────────────────────────────────────────────────────┘"
    fi
}

# -----------------------------------------------------------------------------
# Wizard steps
# -----------------------------------------------------------------------------

## Step 1: Welcome & Prerequisites
_wizard_step_welcome() {
    _wizard_header "Welcome to pimpmytmux!"

    echo "This wizard will help you set up your tmux configuration."
    echo ""

    # Check prerequisites
    echo "Checking prerequisites..."
    echo ""

    local missing=()

    if ! check_command tmux; then
        missing+=("tmux (required)")
    else
        echo "  ✓ tmux $(tmux -V | grep -oE '[0-9]+\.[0-9]+')"
    fi

    if check_command yq; then
        echo "  ✓ yq (YAML parser)"
    else
        echo "  ○ yq (optional, but recommended)"
    fi

    if check_command fzf; then
        echo "  ✓ fzf (fuzzy finder)"
    else
        echo "  ○ fzf (optional, enables fuzzy search)"
    fi

    if check_command gum; then
        echo "  ✓ gum (fancy prompts)"
    else
        echo "  ○ gum (optional, enables fancy UI)"
    fi

    echo ""

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required dependencies:"
        printf '  - %s\n' "${missing[@]}"
        return 1
    fi

    local continue
    continue=$(_wizard_confirm "Continue with setup?")
    [[ "$continue" == "true" ]]
}

## Step 2: Choose theme
_wizard_step_theme() {
    _wizard_step 1 5 "Choose your theme"

    local themes_dir="${PIMPMYTMUX_ROOT}/themes"
    local themes=()

    for theme_file in "$themes_dir"/*.yaml; do
        if [[ -f "$theme_file" ]]; then
            themes+=("$(basename "$theme_file" .yaml)")
        fi
    done

    if [[ ${#themes[@]} -eq 0 ]]; then
        log_warn "No themes found"
        WIZARD_THEME="cyberpunk"
        return 0
    fi

    # Show theme previews if using gum
    if _use_gum; then
        echo "Select a theme (previews shown):"
        echo ""
    fi

    local choice
    choice=$(_wizard_choose "Select a theme:" "${themes[@]}")

    WIZARD_THEME="${choice:-cyberpunk}"
    echo ""
    echo "Selected theme: $WIZARD_THEME"
}

## Step 3: Configure general settings
_wizard_step_general() {
    _wizard_step 2 5 "General settings"

    # Prefix key
    echo "The prefix key is used to trigger tmux commands."
    echo "Common choices: C-b (default), C-a (screen-like), C-Space"
    echo ""

    local prefix
    prefix=$(_wizard_choose "Select prefix key:" "C-b (default)" "C-a (screen-like)" "C-Space (modern)")

    case "$prefix" in
        *C-b*) WIZARD_PREFIX="C-b" ;;
        *C-a*) WIZARD_PREFIX="C-a" ;;
        *C-Space*) WIZARD_PREFIX="C-Space" ;;
        *) WIZARD_PREFIX="C-b" ;;
    esac

    echo ""

    # Mouse support
    local mouse
    mouse=$(_wizard_confirm "Enable mouse support?" "true")
    WIZARD_MOUSE="$mouse"

    # Base index
    local base_index
    base_index=$(_wizard_choose "Start window/pane numbering from:" "1 (recommended)" "0 (traditional)")

    case "$base_index" in
        *1*) WIZARD_BASE_INDEX="1" ;;
        *) WIZARD_BASE_INDEX="0" ;;
    esac
}

## Step 4: Select modules
_wizard_step_modules() {
    _wizard_step 3 5 "Select modules"

    echo "Choose which modules to enable:"
    echo ""

    local modules
    modules=$(_wizard_choose_multi "Select modules to enable:" \
        "sessions - Session save/restore" \
        "navigation - Vim bindings, fzf integration" \
        "devtools - Git status, IDE layouts" \
        "monitoring - CPU, memory, battery")

    WIZARD_MODULES_SESSIONS="false"
    WIZARD_MODULES_NAVIGATION="false"
    WIZARD_MODULES_DEVTOOLS="false"
    WIZARD_MODULES_MONITORING="false"

    while IFS= read -r module; do
        case "$module" in
            sessions*) WIZARD_MODULES_SESSIONS="true" ;;
            navigation*) WIZARD_MODULES_NAVIGATION="true" ;;
            devtools*) WIZARD_MODULES_DEVTOOLS="true" ;;
            monitoring*) WIZARD_MODULES_MONITORING="true" ;;
        esac
    done <<< "$modules"

    echo ""
    echo "Enabled modules:"
    [[ "$WIZARD_MODULES_SESSIONS" == "true" ]] && echo "  ✓ sessions"
    [[ "$WIZARD_MODULES_NAVIGATION" == "true" ]] && echo "  ✓ navigation"
    [[ "$WIZARD_MODULES_DEVTOOLS" == "true" ]] && echo "  ✓ devtools"
    [[ "$WIZARD_MODULES_MONITORING" == "true" ]] && echo "  ✓ monitoring"
}

## Step 5: Navigation options (if enabled)
_wizard_step_navigation() {
    if [[ "$WIZARD_MODULES_NAVIGATION" != "true" ]]; then
        return 0
    fi

    _wizard_step 4 5 "Navigation options"

    local vim_mode
    vim_mode=$(_wizard_confirm "Enable vim-style navigation (hjkl)?" "true")
    WIZARD_NAV_VIM="$vim_mode"

    if check_command fzf; then
        local fzf_integration
        fzf_integration=$(_wizard_confirm "Enable fzf integration for session/window switching?" "true")
        WIZARD_NAV_FZF="$fzf_integration"
    else
        WIZARD_NAV_FZF="false"
    fi

    local smart_splits
    smart_splits=$(_wizard_confirm "Enable smart pane splitting (vim-tmux-navigator compatible)?" "true")
    WIZARD_NAV_SPLITS="$smart_splits"
}

## Step 6: Generate & Preview
_wizard_step_preview() {
    _wizard_step 5 5 "Preview & Confirm"

    echo "Configuration summary:"
    echo ""
    echo "  Theme:           $WIZARD_THEME"
    echo "  Prefix key:      $WIZARD_PREFIX"
    echo "  Mouse:           $WIZARD_MOUSE"
    echo "  Base index:      $WIZARD_BASE_INDEX"
    echo ""
    echo "  Modules:"
    echo "    Sessions:      $WIZARD_MODULES_SESSIONS"
    echo "    Navigation:    $WIZARD_MODULES_NAVIGATION"
    echo "    DevTools:      $WIZARD_MODULES_DEVTOOLS"
    echo "    Monitoring:    $WIZARD_MODULES_MONITORING"

    if [[ "$WIZARD_MODULES_NAVIGATION" == "true" ]]; then
        echo ""
        echo "  Navigation options:"
        echo "    Vim mode:      ${WIZARD_NAV_VIM:-true}"
        echo "    FZF:           ${WIZARD_NAV_FZF:-false}"
        echo "    Smart splits:  ${WIZARD_NAV_SPLITS:-true}"
    fi

    echo ""

    local confirm
    confirm=$(_wizard_confirm "Generate configuration with these settings?")
    [[ "$confirm" == "true" ]]
}

## Generate configuration file from wizard choices
_wizard_generate_config() {
    local config_file="${1:-$PIMPMYTMUX_CONFIG_FILE}"

    cat > "$config_file" << EOF
# pimpmytmux configuration
# Generated by setup wizard on $(date)

# Theme
theme: ${WIZARD_THEME:-cyberpunk}

# General settings
general:
  prefix: ${WIZARD_PREFIX:-C-b}
  mouse: ${WIZARD_MOUSE:-true}
  base_index: ${WIZARD_BASE_INDEX:-1}
  history_limit: 50000
  escape_time: 10
  focus_events: true
  true_color: true

# Window settings
windows:
  renumber: true
  auto_rename: true

# Pane settings
panes:
  retain_path: true
  display_time: 2000

# Status bar
status_bar:
  position: bottom
  interval: 5
  left_length: 40
  right_length: 80

# Modules
modules:
  sessions:
    enabled: ${WIZARD_MODULES_SESSIONS:-false}
    auto_save: false
    auto_restore: false

  navigation:
    enabled: ${WIZARD_MODULES_NAVIGATION:-false}
    vim_mode: ${WIZARD_NAV_VIM:-true}
    fzf_integration: ${WIZARD_NAV_FZF:-false}
    smart_splits: ${WIZARD_NAV_SPLITS:-false}

  devtools:
    enabled: ${WIZARD_MODULES_DEVTOOLS:-false}
    git_status: true
    project_detection: true

  monitoring:
    enabled: ${WIZARD_MODULES_MONITORING:-false}
    cpu: true
    memory: true
    battery: true
    network: false
    weather: false
EOF

    log_success "Configuration saved: $config_file"
}

# -----------------------------------------------------------------------------
# Main wizard function
# -----------------------------------------------------------------------------

## Run the interactive setup wizard
run_wizard() {
    # Initialize wizard variables
    WIZARD_THEME=""
    WIZARD_PREFIX=""
    WIZARD_MOUSE=""
    WIZARD_BASE_INDEX=""
    WIZARD_MODULES_SESSIONS=""
    WIZARD_MODULES_NAVIGATION=""
    WIZARD_MODULES_DEVTOOLS=""
    WIZARD_MODULES_MONITORING=""
    WIZARD_NAV_VIM=""
    WIZARD_NAV_FZF=""
    WIZARD_NAV_SPLITS=""

    # Run wizard steps
    if ! _wizard_step_welcome; then
        log_info "Setup cancelled"
        return 1
    fi

    _wizard_step_theme
    _wizard_step_general
    _wizard_step_modules
    _wizard_step_navigation

    if ! _wizard_step_preview; then
        log_info "Setup cancelled"
        return 1
    fi

    # Create directories
    init_directories

    # Generate configuration
    _wizard_generate_config

    # Apply configuration
    echo ""
    local apply
    apply=$(_wizard_confirm "Apply configuration now?")

    if [[ "$apply" == "true" ]]; then
        log_info "Generating tmux configuration..."
        generate_tmux_conf "$PIMPMYTMUX_CONFIG_FILE" "$(get_tmux_conf_path)"
        setup_tmux_conf_symlink

        echo ""
        _wizard_header "Setup complete!"
        echo ""
        echo "Your tmux configuration is ready!"
        echo ""
        echo "Next steps:"
        echo "  1. Start or restart tmux"
        echo "  2. Run 'pimpmytmux status' to verify"
        echo "  3. Run 'pimpmytmux edit' to customize further"
        echo ""
        echo "Useful commands:"
        echo "  pimpmytmux themes      - List available themes"
        echo "  pimpmytmux theme NAME  - Switch theme"
        echo "  pimpmytmux layouts     - List layouts"
        echo "  pimpmytmux session     - Session management"
        echo ""
    else
        echo ""
        log_info "Configuration saved but not applied."
        log_info "Run 'pimpmytmux apply' when ready."
    fi

    return 0
}

## Quick setup with defaults
quick_setup() {
    _wizard_header "Quick Setup"

    echo "This will create a configuration with sensible defaults."
    echo ""

    local theme
    theme=$(_wizard_choose "Pick a theme:" "cyberpunk" "dracula" "catppuccin" "nord" "gruvbox")

    # Set defaults
    WIZARD_THEME="$theme"
    WIZARD_PREFIX="C-b"
    WIZARD_MOUSE="true"
    WIZARD_BASE_INDEX="1"
    WIZARD_MODULES_SESSIONS="true"
    WIZARD_MODULES_NAVIGATION="true"
    WIZARD_MODULES_DEVTOOLS="true"
    WIZARD_MODULES_MONITORING="true"
    WIZARD_NAV_VIM="true"
    WIZARD_NAV_FZF="$(check_command fzf && echo true || echo false)"
    WIZARD_NAV_SPLITS="true"

    # Create directories
    init_directories

    # Generate and apply
    _wizard_generate_config
    generate_tmux_conf "$PIMPMYTMUX_CONFIG_FILE" "$(get_tmux_conf_path)"
    setup_tmux_conf_symlink

    echo ""
    log_success "Quick setup complete with '$theme' theme!"
    log_info "Run 'pimpmytmux edit' to customize or 'pimpmytmux wizard' for full setup."
}
