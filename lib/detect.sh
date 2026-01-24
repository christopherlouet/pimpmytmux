#!/usr/bin/env bash
# pimpmytmux - Project type detection
# https://github.com/christopherlouet/pimpmytmux

# Guard against re-sourcing
[[ -n "${_PIMPMYTMUX_DETECT_LOADED:-}" ]] && return 0
_PIMPMYTMUX_DETECT_LOADED=1

# shellcheck source=lib/core.sh
source "${PIMPMYTMUX_LIB_DIR:-$(dirname "${BASH_SOURCE[0]}")}/core.sh"

# -----------------------------------------------------------------------------
# Project Type Detection
# -----------------------------------------------------------------------------

## Detect project type based on marker files
## Usage: detect_project_type [directory]
## Returns: node, rust, go, python, ruby, java, php, elixir, unknown
detect_project_type() {
    local dir="${1:-$(pwd)}"

    # Check for project markers in order of specificity
    if [[ -f "$dir/package.json" ]]; then
        echo "node"
    elif [[ -f "$dir/Cargo.toml" ]]; then
        echo "rust"
    elif [[ -f "$dir/go.mod" ]]; then
        echo "go"
    elif [[ -f "$dir/pyproject.toml" ]] || [[ -f "$dir/requirements.txt" ]] || [[ -f "$dir/setup.py" ]]; then
        echo "python"
    elif [[ -f "$dir/Gemfile" ]]; then
        echo "ruby"
    elif [[ -f "$dir/pom.xml" ]] || [[ -f "$dir/build.gradle" ]]; then
        echo "java"
    elif [[ -f "$dir/composer.json" ]]; then
        echo "php"
    elif [[ -f "$dir/mix.exs" ]]; then
        echo "elixir"
    else
        echo "unknown"
    fi
}

## Check if directory is a project root
## Usage: is_project_root [directory]
is_project_root() {
    local dir="${1:-$(pwd)}"
    local type
    type=$(detect_project_type "$dir")
    [[ "$type" != "unknown" ]]
}

## List all supported project types
## Usage: list_project_types
list_project_types() {
    cat << 'EOF'
node      - Node.js (package.json)
rust      - Rust (Cargo.toml)
go        - Go (go.mod)
python    - Python (pyproject.toml, requirements.txt)
ruby      - Ruby (Gemfile)
java      - Java (pom.xml, build.gradle)
php       - PHP (composer.json)
elixir    - Elixir (mix.exs)
EOF
}

# -----------------------------------------------------------------------------
# Layout Recommendation
# -----------------------------------------------------------------------------

## Get recommended layout for project type
## Usage: get_layout_for_project <type>
get_layout_for_project() {
    local type="$1"

    case "$type" in
        node)
            echo "dev-fullstack"
            ;;
        rust|go)
            echo "dev-api"
            ;;
        python)
            echo "dev-fullstack"
            ;;
        ruby)
            echo "dev-fullstack"
            ;;
        java)
            echo "dev-api"
            ;;
        php)
            echo "dev-fullstack"
            ;;
        elixir)
            echo "dev-api"
            ;;
        *)
            echo ""
            ;;
    esac
}

# -----------------------------------------------------------------------------
# Project Info
# -----------------------------------------------------------------------------

## Get project name
## Usage: get_project_name [directory]
get_project_name() {
    local dir="${1:-$(pwd)}"
    local name=""

    # Try to get name from project files
    if [[ -f "$dir/package.json" ]]; then
        name=$(grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' "$dir/package.json" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
    elif [[ -f "$dir/Cargo.toml" ]]; then
        name=$(grep -E '^name[[:space:]]*=' "$dir/Cargo.toml" 2>/dev/null | head -1 | sed 's/.*=[[:space:]]*"\([^"]*\)".*/\1/')
    elif [[ -f "$dir/pyproject.toml" ]]; then
        name=$(grep -E '^name[[:space:]]*=' "$dir/pyproject.toml" 2>/dev/null | head -1 | sed 's/.*=[[:space:]]*"\([^"]*\)".*/\1/')
    fi

    # Fallback to directory name
    if [[ -z "$name" ]]; then
        name=$(basename "$dir")
    fi

    echo "$name"
}

## Get dev command for project
## Usage: get_dev_command [directory]
get_dev_command() {
    local dir="${1:-$(pwd)}"
    local type
    type=$(detect_project_type "$dir")

    case "$type" in
        node)
            # Check package.json for scripts
            if [[ -f "$dir/package.json" ]]; then
                if grep -q '"dev"' "$dir/package.json" 2>/dev/null; then
                    echo "npm run dev"
                elif grep -q '"start"' "$dir/package.json" 2>/dev/null; then
                    echo "npm start"
                else
                    echo "npm run dev"
                fi
            else
                echo "npm run dev"
            fi
            ;;
        rust)
            echo "cargo watch -x run"
            ;;
        go)
            echo "go run ."
            ;;
        python)
            if [[ -f "$dir/manage.py" ]]; then
                echo "python manage.py runserver"
            elif [[ -f "$dir/app.py" ]]; then
                echo "python app.py"
            else
                echo "python -m flask run"
            fi
            ;;
        ruby)
            if [[ -f "$dir/bin/rails" ]]; then
                echo "bin/rails server"
            else
                echo "bundle exec ruby app.rb"
            fi
            ;;
        java)
            if [[ -f "$dir/mvnw" ]]; then
                echo "./mvnw spring-boot:run"
            elif [[ -f "$dir/gradlew" ]]; then
                echo "./gradlew bootRun"
            else
                echo "mvn spring-boot:run"
            fi
            ;;
        php)
            if [[ -f "$dir/artisan" ]]; then
                echo "php artisan serve"
            else
                echo "php -S localhost:8000"
            fi
            ;;
        elixir)
            echo "mix phx.server"
            ;;
        *)
            echo ""
            ;;
    esac
}

## Get test command for project
## Usage: get_test_command [directory]
get_test_command() {
    local dir="${1:-$(pwd)}"
    local type
    type=$(detect_project_type "$dir")

    case "$type" in
        node)
            echo "npm test"
            ;;
        rust)
            echo "cargo test"
            ;;
        go)
            echo "go test ./..."
            ;;
        python)
            echo "pytest"
            ;;
        ruby)
            echo "bundle exec rspec"
            ;;
        java)
            if [[ -f "$dir/mvnw" ]]; then
                echo "./mvnw test"
            else
                echo "mvn test"
            fi
            ;;
        php)
            echo "vendor/bin/phpunit"
            ;;
        elixir)
            echo "mix test"
            ;;
        *)
            echo ""
            ;;
    esac
}

## Get build command for project
## Usage: get_build_command [directory]
get_build_command() {
    local dir="${1:-$(pwd)}"
    local type
    type=$(detect_project_type "$dir")

    case "$type" in
        node)
            echo "npm run build"
            ;;
        rust)
            echo "cargo build --release"
            ;;
        go)
            echo "go build"
            ;;
        python)
            echo "python -m build"
            ;;
        ruby)
            echo "bundle exec rake build"
            ;;
        java)
            if [[ -f "$dir/mvnw" ]]; then
                echo "./mvnw package"
            else
                echo "mvn package"
            fi
            ;;
        php)
            echo "composer build"
            ;;
        elixir)
            echo "mix release"
            ;;
        *)
            echo ""
            ;;
    esac
}

# -----------------------------------------------------------------------------
# Auto-detection Support
# -----------------------------------------------------------------------------

## Apply layout based on detected project type
## Usage: apply_project_layout [directory]
apply_project_layout() {
    local dir="${1:-$(pwd)}"
    local type layout

    type=$(detect_project_type "$dir")
    if [[ "$type" == "unknown" ]]; then
        log_warn "Could not detect project type in: $dir"
        return 1
    fi

    layout=$(get_layout_for_project "$type")
    if [[ -z "$layout" ]]; then
        log_warn "No layout configured for project type: $type"
        return 1
    fi

    log_info "Detected $type project, applying $layout layout"

    # Apply the layout using the layouts module if available
    if check_command apply_layout; then
        apply_layout "$layout"
    else
        log_warn "Layout module not available"
        return 1
    fi
}

## Show detected project info
## Usage: show_project_info [directory]
show_project_info() {
    local dir="${1:-$(pwd)}"
    local type name layout dev_cmd test_cmd

    type=$(detect_project_type "$dir")
    name=$(get_project_name "$dir")
    layout=$(get_layout_for_project "$type")
    dev_cmd=$(get_dev_command "$dir")
    test_cmd=$(get_test_command "$dir")

    echo ""
    echo -e "${BOLD}Project Info${RESET}"
    echo "────────────────────────────────────"
    echo -e "Name:      ${CYAN}$name${RESET}"
    echo -e "Type:      ${CYAN}$type${RESET}"
    echo -e "Path:      ${DIM}$dir${RESET}"
    echo ""
    if [[ -n "$layout" ]]; then
        echo -e "Layout:    ${GREEN}$layout${RESET}"
    fi
    if [[ -n "$dev_cmd" ]]; then
        echo -e "Dev:       ${DIM}$dev_cmd${RESET}"
    fi
    if [[ -n "$test_cmd" ]]; then
        echo -e "Test:      ${DIM}$test_cmd${RESET}"
    fi
    echo ""
}
