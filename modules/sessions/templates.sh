#!/usr/bin/env bash
# pimpmytmux - Session template functionality
# Allows creating multi-window sessions from YAML templates
# https://github.com/christopherlouet/pimpmytmux

# Guard against re-sourcing
[[ -n "${_PIMPMYTMUX_SESSION_TEMPLATES_LOADED:-}" ]] && return 0
_PIMPMYTMUX_SESSION_TEMPLATES_LOADED=1

# shellcheck source=lib/core.sh
source "${PIMPMYTMUX_LIB_DIR:-$(dirname "${BASH_SOURCE[0]}")/../../lib}/core.sh"

# -----------------------------------------------------------------------------
# Constants
# -----------------------------------------------------------------------------

PIMPMYTMUX_SESSION_TEMPLATES_DIR="${PIMPMYTMUX_SESSION_TEMPLATES_DIR:-${PIMPMYTMUX_CONFIG_DIR}/session-templates}"

# -----------------------------------------------------------------------------
# Template Listing
# -----------------------------------------------------------------------------

## List all available session templates
## Usage: list_session_templates
list_session_templates() {
    if [[ ! -d "$PIMPMYTMUX_SESSION_TEMPLATES_DIR" ]]; then
        return 0
    fi

    local templates=()
    for file in "$PIMPMYTMUX_SESSION_TEMPLATES_DIR"/*.yaml; do
        if [[ -f "$file" ]]; then
            templates+=("$(basename "$file" .yaml)")
        fi
    done

    printf '%s\n' "${templates[@]}" | sort
}

## Check if a template exists
## Usage: template_exists <name>
template_exists() {
    local name="$1"
    [[ -f "$PIMPMYTMUX_SESSION_TEMPLATES_DIR/${name}.yaml" ]]
}

# -----------------------------------------------------------------------------
# Template Loading
# -----------------------------------------------------------------------------

## Get template file path
## Usage: get_template_path <name>
get_template_path() {
    local name="$1"
    echo "$PIMPMYTMUX_SESSION_TEMPLATES_DIR/${name}.yaml"
}

## Load a session template
## Usage: load_session_template <name>
load_session_template() {
    local name="$1"
    local template_file
    template_file=$(get_template_path "$name")

    if [[ ! -f "$template_file" ]]; then
        log_error "Template not found: $name"
        return 1
    fi

    log_debug "Loaded template: $template_file"
}

## Get template session name
## Usage: get_template_name <template>
get_template_name() {
    local template="$1"
    local template_file
    template_file=$(get_template_path "$template")

    if [[ ! -f "$template_file" ]]; then
        echo "$template"
        return
    fi

    local name
    if check_command yq; then
        name=$(yq eval '.name // ""' "$template_file" 2>/dev/null)
    fi

    if [[ -z "$name" || "$name" == "null" ]]; then
        echo "$template"
    else
        echo "$name"
    fi
}

# -----------------------------------------------------------------------------
# Variable Substitution
# -----------------------------------------------------------------------------

## Expand template variables in a string
## Usage: expand_template_vars <string>
## Supported variables:
##   ${PROJECT_NAME}  - Current project name
##   ${PROJECT_ROOT}  - Current project root directory
##   ${EDITOR}        - User's preferred editor
##   ${HOME}          - User's home directory
##   ${USER}          - Current username
expand_template_vars() {
    local input="$1"
    local result="$input"

    # Expand known variables
    result="${result//\$\{PROJECT_NAME\}/${PROJECT_NAME:-}}"
    result="${result//\$\{PROJECT_ROOT\}/${PROJECT_ROOT:-}}"
    result="${result//\$\{EDITOR\}/${EDITOR:-vim}}"
    result="${result//\$\{HOME\}/${HOME}}"
    result="${result//\$\{USER\}/${USER}}"

    echo "$result"
}

# -----------------------------------------------------------------------------
# Template Window Access
# -----------------------------------------------------------------------------

## Get number of windows in template
## Usage: get_template_window_count <template>
get_template_window_count() {
    local template="$1"
    local template_file
    template_file=$(get_template_path "$template")

    if [[ ! -f "$template_file" ]]; then
        echo "0"
        return
    fi

    if check_command yq; then
        yq eval '.windows | length' "$template_file" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

## Get window name at index
## Usage: get_template_window_name <template> <index>
get_template_window_name() {
    local template="$1"
    local index="$2"
    local template_file
    template_file=$(get_template_path "$template")

    if [[ ! -f "$template_file" ]]; then
        echo ""
        return
    fi

    if check_command yq; then
        local name
        name=$(yq eval ".windows[$index].name // \"\"" "$template_file" 2>/dev/null)
        if [[ -z "$name" || "$name" == "null" ]]; then
            echo "window-$index"
        else
            echo "$name"
        fi
    else
        echo "window-$index"
    fi
}

## Get window layout at index
## Usage: get_template_window_layout <template> <index>
get_template_window_layout() {
    local template="$1"
    local index="$2"
    local template_file
    template_file=$(get_template_path "$template")

    if check_command yq; then
        yq eval ".windows[$index].layout // \"\"" "$template_file" 2>/dev/null
    fi
}

## Get window directory at index
## Usage: get_template_window_dir <template> <index>
get_template_window_dir() {
    local template="$1"
    local index="$2"
    local template_file
    template_file=$(get_template_path "$template")

    if check_command yq; then
        local dir
        dir=$(yq eval ".windows[$index].directory // \"\"" "$template_file" 2>/dev/null)
        expand_template_vars "$dir"
    fi
}

# -----------------------------------------------------------------------------
# Template Validation
# -----------------------------------------------------------------------------

## Validate a session template
## Usage: validate_session_template <name>
validate_session_template() {
    local name="$1"
    local template_file
    template_file=$(get_template_path "$name")

    if [[ ! -f "$template_file" ]]; then
        log_error "Template not found: $name"
        return 1
    fi

    # Check for required fields
    if check_command yq; then
        local has_windows
        has_windows=$(yq eval '.windows | length' "$template_file" 2>/dev/null)

        if [[ -z "$has_windows" || "$has_windows" == "0" || "$has_windows" == "null" ]]; then
            log_error "Template must have at least one window defined in 'windows'"
            return 1
        fi
    fi

    log_debug "Template validated: $name"
}

# -----------------------------------------------------------------------------
# Template Application
# -----------------------------------------------------------------------------

## Apply a session template
## Usage: apply_session_template <name> [session_name]
apply_session_template() {
    local template="$1"
    local session_name="${2:-}"

    # Validate template
    if ! validate_session_template "$template"; then
        return 1
    fi

    # Get session name from template if not provided
    if [[ -z "$session_name" ]]; then
        session_name=$(get_template_name "$template")
        session_name=$(expand_template_vars "$session_name")
    fi

    local window_count
    window_count=$(get_template_window_count "$template")

    log_info "Creating session '$session_name' with $window_count window(s)"

    # Check if already inside tmux
    if is_inside_tmux; then
        log_warn "Already inside tmux. Creating new session attached."
    fi

    # Create the session with first window
    local first_window_name
    first_window_name=$(get_template_window_name "$template" 0)
    first_window_name=$(expand_template_vars "$first_window_name")

    local first_window_dir
    first_window_dir=$(get_template_window_dir "$template" 0)

    if [[ -n "$first_window_dir" && -d "$first_window_dir" ]]; then
        tmux new-session -d -s "$session_name" -n "$first_window_name" -c "$first_window_dir" 2>/dev/null || {
            log_error "Failed to create session: $session_name"
            return 1
        }
    else
        tmux new-session -d -s "$session_name" -n "$first_window_name" 2>/dev/null || {
            log_error "Failed to create session: $session_name"
            return 1
        }
    fi

    # Create additional windows
    for ((i = 1; i < window_count; i++)); do
        local window_name window_dir
        window_name=$(get_template_window_name "$template" "$i")
        window_name=$(expand_template_vars "$window_name")
        window_dir=$(get_template_window_dir "$template" "$i")

        if [[ -n "$window_dir" && -d "$window_dir" ]]; then
            tmux new-window -t "$session_name" -n "$window_name" -c "$window_dir"
        else
            tmux new-window -t "$session_name" -n "$window_name"
        fi

        log_debug "Created window: $window_name"
    done

    # Apply layouts to each window
    for ((i = 0; i < window_count; i++)); do
        local layout
        layout=$(get_template_window_layout "$template" "$i")

        if [[ -n "$layout" && "$layout" != "null" ]]; then
            tmux select-layout -t "${session_name}:$i" "$layout" 2>/dev/null || true
        fi
    done

    # Select first window
    tmux select-window -t "${session_name}:0"

    log_success "Session '$session_name' created from template '$template'"

    # Attach if not already in tmux
    if ! is_inside_tmux; then
        tmux attach-session -t "$session_name"
    fi
}

# -----------------------------------------------------------------------------
# Template Creation
# -----------------------------------------------------------------------------

## Create a session template from current session
## Usage: save_as_template <name>
save_as_template() {
    local name="$1"

    if ! is_inside_tmux; then
        log_error "Must be inside tmux to save session as template"
        return 1
    fi

    ensure_dir "$PIMPMYTMUX_SESSION_TEMPLATES_DIR"

    local template_file="$PIMPMYTMUX_SESSION_TEMPLATES_DIR/${name}.yaml"

    if [[ -f "$template_file" ]]; then
        log_warn "Template already exists: $name"
        read -rp "Overwrite? [y/N] " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log_info "Cancelled"
            return 0
        fi
    fi

    local session_name
    session_name=$(tmux display-message -p '#S')

    # Start building the template
    cat > "$template_file" << EOF
# Session template: $name
# Created from session: $session_name
# Date: $(date +%Y-%m-%d)

name: $name

windows:
EOF

    # Capture each window
    local windows
    windows=$(tmux list-windows -t "$session_name" -F '#{window_index}:#{window_name}:#{window_layout}')

    while IFS=':' read -r index wname layout; do
        local cwd
        cwd=$(tmux display-message -p -t "${session_name}:${index}" '#{pane_current_path}')

        cat >> "$template_file" << EOF
  - name: $wname
    layout: $layout
    directory: $cwd
EOF
    done <<< "$windows"

    log_success "Saved session as template: $name"
    log_info "Template file: $template_file"
}

## Initialize session templates directory with examples
## Usage: init_session_templates
init_session_templates() {
    ensure_dir "$PIMPMYTMUX_SESSION_TEMPLATES_DIR"

    # Create example development template
    if [[ ! -f "$PIMPMYTMUX_SESSION_TEMPLATES_DIR/development.yaml" ]]; then
        cat > "$PIMPMYTMUX_SESSION_TEMPLATES_DIR/development.yaml" << 'EOF'
# Development session template
name: ${PROJECT_NAME}-dev

windows:
  - name: editor
    layout: main-vertical
    directory: ${PROJECT_ROOT}
    panes:
      - command: ${EDITOR} .

  - name: terminal
    layout: even-horizontal
    directory: ${PROJECT_ROOT}

  - name: logs
    layout: even-vertical
    directory: ${PROJECT_ROOT}
    panes:
      - command: tail -f logs/*.log 2>/dev/null || echo "No logs found"
EOF
        log_info "Created example template: development.yaml"
    fi

    # Create example fullstack template
    if [[ ! -f "$PIMPMYTMUX_SESSION_TEMPLATES_DIR/fullstack.yaml" ]]; then
        cat > "$PIMPMYTMUX_SESSION_TEMPLATES_DIR/fullstack.yaml" << 'EOF'
# Fullstack development session template
name: ${PROJECT_NAME}

windows:
  - name: frontend
    layout: main-vertical
    directory: ${PROJECT_ROOT}/frontend

  - name: backend
    layout: main-vertical
    directory: ${PROJECT_ROOT}/backend

  - name: database
    layout: even-horizontal
    directory: ${PROJECT_ROOT}

  - name: git
    layout: even-horizontal
    directory: ${PROJECT_ROOT}
EOF
        log_info "Created example template: fullstack.yaml"
    fi
}
