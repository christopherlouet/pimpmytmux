#!/usr/bin/env bash
# pimpmytmux - Project detection and templates
# Auto-detect project type and apply appropriate layout

# Guard against re-sourcing
[[ -n "${_PIMPMYTMUX_PROJECT_TEMPLATES_LOADED:-}" ]] && return 0
_PIMPMYTMUX_PROJECT_TEMPLATES_LOADED=1

# -----------------------------------------------------------------------------
# Project detection
# -----------------------------------------------------------------------------

## Detect project type from directory
detect_project_type() {
    local dir="${1:-$(pwd)}"

    # Node.js / JavaScript
    if [[ -f "$dir/package.json" ]]; then
        if grep -q '"next"' "$dir/package.json" 2>/dev/null; then
            echo "nextjs"
        elif grep -q '"react"' "$dir/package.json" 2>/dev/null; then
            echo "react"
        elif grep -q '"vue"' "$dir/package.json" 2>/dev/null; then
            echo "vue"
        else
            echo "nodejs"
        fi
        return
    fi

    # Python
    if [[ -f "$dir/pyproject.toml" || -f "$dir/setup.py" || -f "$dir/requirements.txt" ]]; then
        if [[ -f "$dir/manage.py" ]]; then
            echo "django"
        elif grep -q "fastapi" "$dir/requirements.txt" 2>/dev/null; then
            echo "fastapi"
        elif grep -q "flask" "$dir/requirements.txt" 2>/dev/null; then
            echo "flask"
        else
            echo "python"
        fi
        return
    fi

    # Go
    if [[ -f "$dir/go.mod" ]]; then
        echo "go"
        return
    fi

    # Rust
    if [[ -f "$dir/Cargo.toml" ]]; then
        echo "rust"
        return
    fi

    # Ruby
    if [[ -f "$dir/Gemfile" ]]; then
        if [[ -f "$dir/config/application.rb" ]]; then
            echo "rails"
        else
            echo "ruby"
        fi
        return
    fi

    # Flutter / Dart
    if [[ -f "$dir/pubspec.yaml" ]]; then
        echo "flutter"
        return
    fi

    # Java / Kotlin
    if [[ -f "$dir/pom.xml" || -f "$dir/build.gradle" || -f "$dir/build.gradle.kts" ]]; then
        echo "java"
        return
    fi

    # Terraform
    if ls "$dir"/*.tf &>/dev/null; then
        echo "terraform"
        return
    fi

    # Docker
    if [[ -f "$dir/docker-compose.yml" || -f "$dir/docker-compose.yaml" ]]; then
        echo "docker"
        return
    fi

    # Generic git project
    if [[ -d "$dir/.git" ]]; then
        echo "git"
        return
    fi

    echo "generic"
}

## Get project name from directory
get_project_name() {
    local dir="${1:-$(pwd)}"
    basename "$dir"
}

# -----------------------------------------------------------------------------
# Project templates
# -----------------------------------------------------------------------------

## Apply template for Node.js project
apply_template_nodejs() {
    local dir="${1:-$(pwd)}"

    # Layout: editor | terminal + server
    tmux split-window -h -p 40 -c "$dir"
    tmux split-window -v -p 50 -c "$dir"

    # Start dev server in bottom-right
    if [[ -f "$dir/package.json" ]]; then
        tmux send-keys -t 2 "npm run dev 2>/dev/null || npm start 2>/dev/null || echo 'No dev script found'" Enter
    fi

    tmux select-pane -t 0
}

## Apply template for Python project
apply_template_python() {
    local dir="${1:-$(pwd)}"

    tmux split-window -h -p 35 -c "$dir"

    # Activate venv if exists
    if [[ -d "$dir/.venv" ]]; then
        tmux send-keys -t 1 "source .venv/bin/activate" Enter
    elif [[ -d "$dir/venv" ]]; then
        tmux send-keys -t 1 "source venv/bin/activate" Enter
    fi

    tmux select-pane -t 0
}

## Apply template for Go project
apply_template_go() {
    local dir="${1:-$(pwd)}"

    tmux split-window -h -p 40 -c "$dir"
    tmux split-window -v -p 50 -c "$dir"

    tmux select-pane -t 0
}

## Apply template for Rust project
apply_template_rust() {
    local dir="${1:-$(pwd)}"

    tmux split-window -h -p 40 -c "$dir"
    tmux split-window -v -p 50 -c "$dir"

    # cargo watch if available
    tmux send-keys -t 2 "cargo watch -x check 2>/dev/null || echo 'cargo watch not installed'" Enter

    tmux select-pane -t 0
}

## Apply template for Flutter project
apply_template_flutter() {
    local dir="${1:-$(pwd)}"

    tmux split-window -h -p 40 -c "$dir"
    tmux split-window -v -p 50 -c "$dir"

    # Run flutter in bottom pane
    tmux send-keys -t 2 "flutter run 2>/dev/null || echo 'Connect device first'" Enter

    tmux select-pane -t 0
}

## Apply template for Docker project
apply_template_docker() {
    local dir="${1:-$(pwd)}"

    tmux split-window -h -p 40 -c "$dir"
    tmux split-window -v -p 50 -c "$dir"

    # Show docker status
    tmux send-keys -t 1 "docker ps" Enter
    tmux send-keys -t 2 "docker-compose logs -f 2>/dev/null || docker compose logs -f 2>/dev/null" Enter

    tmux select-pane -t 0
}

## Apply template for Terraform project
apply_template_terraform() {
    local dir="${1:-$(pwd)}"

    tmux split-window -h -p 40 -c "$dir"

    # Show terraform state
    tmux send-keys -t 1 "terraform init 2>/dev/null; terraform plan" Enter

    tmux select-pane -t 0
}

## Apply generic template
apply_template_generic() {
    local dir="${1:-$(pwd)}"

    tmux split-window -h -p 35 -c "$dir"
    tmux select-pane -t 0
}

# -----------------------------------------------------------------------------
# Main functions
# -----------------------------------------------------------------------------

## Apply appropriate template for current directory
apply_project_template() {
    local dir="${1:-$(pwd)}"
    local project_type

    project_type=$(detect_project_type "$dir")

    echo "Detected project type: $project_type"

    case "$project_type" in
        nextjs|react|vue|nodejs)
            apply_template_nodejs "$dir"
            ;;
        django|fastapi|flask|python)
            apply_template_python "$dir"
            ;;
        go)
            apply_template_go "$dir"
            ;;
        rust)
            apply_template_rust "$dir"
            ;;
        flutter)
            apply_template_flutter "$dir"
            ;;
        docker)
            apply_template_docker "$dir"
            ;;
        terraform)
            apply_template_terraform "$dir"
            ;;
        rails|ruby|java|git|generic|*)
            apply_template_generic "$dir"
            ;;
    esac
}

## Create new window with project template
new_project_window() {
    local dir="${1:-$(pwd)}"
    local name

    name=$(get_project_name "$dir")

    tmux new-window -n "$name" -c "$dir"
    apply_project_template "$dir"
}
