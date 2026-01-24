#!/usr/bin/env bash
# pimpmytmux installer
# https://github.com/christopherlouet/pimpmytmux
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/christopherlouet/pimpmytmux/main/install.sh | bash
#   or
#   git clone https://github.com/christopherlouet/pimpmytmux.git && cd pimpmytmux && ./install.sh

set -euo pipefail

# -----------------------------------------------------------------------------
# Colors and formatting
# -----------------------------------------------------------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# Disable colors if not interactive
if [[ ! -t 1 ]]; then
    RED='' GREEN='' YELLOW='' BLUE='' MAGENTA='' CYAN='' BOLD='' DIM='' RESET=''
fi

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------

info() {
    echo -e "${GREEN}[INFO]${RESET} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${RESET} $*"
}

error() {
    echo -e "${RED}[ERROR]${RESET} $*" >&2
}

success() {
    echo -e "${GREEN}[OK]${RESET} $*"
}

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

PIMPMYTMUX_VERSION="0.2.1"
PIMPMYTMUX_REPO="https://github.com/christopherlouet/pimpmytmux.git"
PIMPMYTMUX_INSTALL_DIR="${PIMPMYTMUX_INSTALL_DIR:-$HOME/.pimpmytmux}"
PIMPMYTMUX_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/pimpmytmux"
PIMPMYTMUX_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/pimpmytmux"
PIMPMYTMUX_BIN_DIR="${HOME}/.local/bin"

# -----------------------------------------------------------------------------
# Platform detection
# -----------------------------------------------------------------------------

get_platform() {
    local uname_out
    uname_out="$(uname -s)"

    case "${uname_out}" in
        Linux*)
            if grep -qEi "(microsoft|wsl)" /proc/version 2>/dev/null; then
                echo "wsl"
            else
                echo "linux"
            fi
            ;;
        Darwin*)
            echo "macos"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

PLATFORM=$(get_platform)

# -----------------------------------------------------------------------------
# Utility functions
# -----------------------------------------------------------------------------

check_command() {
    command -v "$1" &>/dev/null
}

# -----------------------------------------------------------------------------
# Package manager detection
# -----------------------------------------------------------------------------

detect_package_manager() {
    if check_command brew; then
        echo "brew"
    elif check_command apt-get; then
        echo "apt"
    elif check_command dnf; then
        echo "dnf"
    elif check_command pacman; then
        echo "pacman"
    elif check_command apk; then
        echo "apk"
    elif check_command zypper; then
        echo "zypper"
    else
        echo "unknown"
    fi
}

# -----------------------------------------------------------------------------
# Dependency checks
# -----------------------------------------------------------------------------

check_dependencies() {
    local missing=()

    # Required
    if ! check_command tmux; then
        missing+=("tmux")
    fi

    if ! check_command git; then
        missing+=("git")
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing required dependencies: ${missing[*]}"
        echo ""
        echo "Install them with:"
        case "$PLATFORM" in
            macos)
                echo "  brew install ${missing[*]}"
                ;;
            linux|wsl)
                echo "  sudo apt install ${missing[*]}  # Debian/Ubuntu"
                echo "  sudo dnf install ${missing[*]}  # Fedora"
                echo "  sudo pacman -S ${missing[*]}    # Arch"
                ;;
        esac
        exit 1
    fi

    # Check tmux version
    local tmux_version
    tmux_version=$(tmux -V | sed 's/[^0-9.]//g')
    local major minor
    major=$(echo "$tmux_version" | cut -d. -f1)
    minor=$(echo "$tmux_version" | cut -d. -f2)

    if [[ "$major" -lt 3 ]] || [[ "$major" -eq 3 && "$minor" -lt 2 ]]; then
        warn "tmux version $tmux_version detected. Recommended: 3.2+"
    else
        success "tmux $tmux_version"
    fi

    # Optional dependencies
    echo ""
    info "Checking optional dependencies..."

    if check_command yq; then
        success "yq (YAML parser)"
    else
        warn "yq not found - install for better YAML support"
        echo "  Install: https://github.com/mikefarah/yq#install"
    fi

    if check_command fzf; then
        success "fzf (fuzzy finder)"
    else
        warn "fzf not found - install for fuzzy navigation"
        echo "  Install: https://github.com/junegunn/fzf#installation"
    fi

    if check_command gum; then
        success "gum (TUI toolkit)"
    else
        info "gum not found - optional for interactive wizard"
    fi

    if check_command jq; then
        success "jq (JSON parser)"
    else
        info "jq not found - optional for session management"
    fi

    # Monitoring layout optional dependencies
    echo ""
    info "Checking monitoring layout dependencies..."

    if check_command htop; then
        success "htop (process monitor)"
    else
        info "htop not found - optional for monitoring layout"
    fi

    if check_command duf; then
        success "duf (disk usage)"
    else
        info "duf not found - optional for colorful disk usage"
    fi

    if check_command ccze; then
        success "ccze (log colorizer)"
    else
        info "ccze not found - optional for colorized logs"
    fi
}

# -----------------------------------------------------------------------------
# Interactive dependency installation
# -----------------------------------------------------------------------------

## Ask user for confirmation
confirm() {
    local prompt="$1"
    local default="${2:-n}"

    if [[ "$default" == "y" ]]; then
        read -rp "$prompt [Y/n] " answer
        [[ -z "$answer" || "$answer" =~ ^[Yy] ]]
    else
        read -rp "$prompt [y/N] " answer
        [[ "$answer" =~ ^[Yy] ]]
    fi
}

## Install a package using the detected package manager
install_package() {
    local pkg="$1"
    local pkg_manager="$2"

    case "$pkg_manager" in
        brew)
            brew install "$pkg"
            ;;
        apt)
            sudo apt-get update && sudo apt-get install -y "$pkg"
            ;;
        dnf)
            sudo dnf install -y "$pkg"
            ;;
        pacman)
            sudo pacman -S --noconfirm "$pkg"
            ;;
        apk)
            sudo apk add "$pkg"
            ;;
        zypper)
            sudo zypper install -y "$pkg"
            ;;
        *)
            return 1
            ;;
    esac
}

## Install yq (Go version) - binary download for Linux, brew for macOS
install_yq() {
    local pkg_manager="$1"

    if [[ "$pkg_manager" == "brew" ]]; then
        brew install yq
    else
        info "Downloading yq binary..."
        local arch
        arch=$(uname -m)
        case "$arch" in
            x86_64) arch="amd64" ;;
            aarch64|arm64) arch="arm64" ;;
            armv7l) arch="arm" ;;
            *) error "Unsupported architecture: $arch"; return 1 ;;
        esac

        local os="linux"
        [[ "$PLATFORM" == "macos" ]] && os="darwin"

        local url="https://github.com/mikefarah/yq/releases/latest/download/yq_${os}_${arch}"
        local dest="/usr/local/bin/yq"

        if sudo wget -qO "$dest" "$url" 2>/dev/null || sudo curl -fsSL -o "$dest" "$url" 2>/dev/null; then
            sudo chmod +x "$dest"
            success "Installed yq to $dest"
        else
            error "Failed to download yq"
            return 1
        fi
    fi
}

## Install gum - binary download for Linux, brew for macOS
install_gum() {
    local pkg_manager="$1"

    if [[ "$pkg_manager" == "brew" ]]; then
        brew install gum
    elif [[ "$pkg_manager" == "apt" ]]; then
        # gum has an official apt repository
        info "Adding Charm repository for gum..."
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg 2>/dev/null || true
        echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list > /dev/null
        sudo apt-get update && sudo apt-get install -y gum
    elif [[ "$pkg_manager" == "pacman" ]]; then
        # gum is in AUR, try yay or paru
        if check_command yay; then
            yay -S --noconfirm gum
        elif check_command paru; then
            paru -S --noconfirm gum
        else
            warn "gum is in AUR. Install with: yay -S gum"
            return 1
        fi
    else
        info "Downloading gum binary..."
        local arch
        arch=$(uname -m)
        case "$arch" in
            x86_64) arch="x86_64" ;;
            aarch64|arm64) arch="arm64" ;;
            *) error "Unsupported architecture: $arch"; return 1 ;;
        esac

        local os="Linux"
        [[ "$PLATFORM" == "macos" ]] && os="Darwin"

        local version="0.13.0"
        local url="https://github.com/charmbracelet/gum/releases/download/v${version}/gum_${version}_${os}_${arch}.tar.gz"
        local tmpdir
        tmpdir=$(mktemp -d)

        if curl -fsSL "$url" | tar -xzf - -C "$tmpdir" 2>/dev/null; then
            sudo mv "${tmpdir}/gum" /usr/local/bin/gum
            sudo chmod +x /usr/local/bin/gum
            rm -rf "$tmpdir"
            success "Installed gum to /usr/local/bin/gum"
        else
            rm -rf "$tmpdir"
            error "Failed to download gum"
            return 1
        fi
    fi
}

## Install duf - binary download for Linux, brew for macOS
install_duf() {
    local pkg_manager="$1"

    if [[ "$pkg_manager" == "brew" ]]; then
        brew install duf
    elif [[ "$pkg_manager" == "apt" ]]; then
        # Try apt first (available in newer Ubuntu/Debian)
        if sudo apt-get install -y duf 2>/dev/null; then
            return 0
        fi
        # Fallback to binary download
        install_duf_binary
    elif [[ "$pkg_manager" == "pacman" ]]; then
        sudo pacman -S --noconfirm duf
    elif [[ "$pkg_manager" == "dnf" ]]; then
        sudo dnf install -y duf
    else
        install_duf_binary
    fi
}

## Install duf binary directly
install_duf_binary() {
    info "Downloading duf binary..."
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64) arch="amd64" ;;
        aarch64|arm64) arch="arm64" ;;
        armv7l) arch="armv7" ;;
        *) error "Unsupported architecture: $arch"; return 1 ;;
    esac

    local os="linux"
    [[ "$PLATFORM" == "macos" ]] && os="darwin"

    local version="0.8.1"
    local url="https://github.com/muesli/duf/releases/download/v${version}/duf_${version}_${os}_${arch}.tar.gz"
    local tmpdir
    tmpdir=$(mktemp -d)

    if curl -fsSL "$url" | tar -xzf - -C "$tmpdir" 2>/dev/null; then
        sudo mv "${tmpdir}/duf" /usr/local/bin/duf
        sudo chmod +x /usr/local/bin/duf
        rm -rf "$tmpdir"
        success "Installed duf to /usr/local/bin/duf"
    else
        rm -rf "$tmpdir"
        error "Failed to download duf"
        return 1
    fi
}

## Interactively install optional dependencies
install_optional_dependencies() {
    local pkg_manager
    pkg_manager=$(detect_package_manager)

    if [[ "$pkg_manager" == "unknown" ]]; then
        warn "Could not detect package manager. Please install dependencies manually."
        return 0
    fi

    echo ""
    info "Package manager detected: ${CYAN}$pkg_manager${RESET}"
    echo ""

    local missing_deps=()

    # Check which dependencies are missing
    check_command yq || missing_deps+=("yq")
    check_command fzf || missing_deps+=("fzf")
    check_command gum || missing_deps+=("gum")
    check_command jq || missing_deps+=("jq")
    check_command htop || missing_deps+=("htop")
    check_command duf || missing_deps+=("duf")
    check_command ccze || missing_deps+=("ccze")

    if [[ ${#missing_deps[@]} -eq 0 ]]; then
        success "All optional dependencies are already installed!"
        return 0
    fi

    echo "The following optional dependencies are missing:"
    for dep in "${missing_deps[@]}"; do
        case "$dep" in
            yq)   echo "  - ${BOLD}yq${RESET}: Better YAML parsing (recommended)" ;;
            fzf)  echo "  - ${BOLD}fzf${RESET}: Fuzzy finder for session/window switching" ;;
            gum)  echo "  - ${BOLD}gum${RESET}: Interactive wizard UI" ;;
            jq)   echo "  - ${BOLD}jq${RESET}: JSON parsing for session management" ;;
            htop) echo "  - ${BOLD}htop${RESET}: Interactive process monitor (monitoring layout)" ;;
            duf)  echo "  - ${BOLD}duf${RESET}: Colorful disk usage (monitoring layout)" ;;
            ccze) echo "  - ${BOLD}ccze${RESET}: Log colorizer (monitoring layout)" ;;
        esac
    done
    echo ""

    # Ask about each dependency
    for dep in "${missing_deps[@]}"; do
        local desc
        case "$dep" in
            yq)
                desc="yq (YAML parser - recommended)"
                ;;
            fzf)
                desc="fzf (fuzzy finder)"
                ;;
            gum)
                desc="gum (interactive UI)"
                ;;
            jq)
                desc="jq (JSON parser)"
                ;;
            htop)
                desc="htop (process monitor)"
                ;;
            duf)
                desc="duf (disk usage)"
                ;;
            ccze)
                desc="ccze (log colorizer)"
                ;;
        esac

        if confirm "Install ${BOLD}$desc${RESET}?"; then
            info "Installing $dep..."
            if [[ "$dep" == "yq" ]]; then
                install_yq "$pkg_manager" && success "Installed $dep" || warn "Failed to install $dep"
            elif [[ "$dep" == "gum" ]]; then
                install_gum "$pkg_manager" && success "Installed $dep" || warn "Failed to install $dep"
            elif [[ "$dep" == "duf" ]]; then
                install_duf "$pkg_manager" && success "Installed $dep" || warn "Failed to install $dep"
            else
                install_package "$dep" "$pkg_manager" && success "Installed $dep" || warn "Failed to install $dep"
            fi
            echo ""
        else
            info "Skipping $dep"
        fi
    done
}

# -----------------------------------------------------------------------------
# Backup existing configuration
# -----------------------------------------------------------------------------

backup_existing() {
    local backup_dir="${PIMPMYTMUX_DATA_DIR}/backups"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)

    mkdir -p "$backup_dir"

    # Backup existing .tmux.conf
    if [[ -f "$HOME/.tmux.conf" && ! -L "$HOME/.tmux.conf" ]]; then
        info "Backing up existing ~/.tmux.conf"
        cp "$HOME/.tmux.conf" "${backup_dir}/tmux.conf.${timestamp}.bak"
        success "Backed up to ${backup_dir}/tmux.conf.${timestamp}.bak"
    fi

    # Backup existing pimpmytmux config
    if [[ -f "${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml" ]]; then
        info "Backing up existing pimpmytmux config"
        cp "${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml" "${backup_dir}/pimpmytmux.yaml.${timestamp}.bak"
        success "Backed up to ${backup_dir}/pimpmytmux.yaml.${timestamp}.bak"
    fi
}

# -----------------------------------------------------------------------------
# Installation
# -----------------------------------------------------------------------------

install_pimpmytmux() {
    echo ""
    echo -e "${BOLD}${MAGENTA}"
    cat << 'EOF'
       _                                _
 _ __ (_)_ __ ___  _ __  _ __ ___  _   | |_ _ __ ___  _   ___  __
| '_ \| | '_ ` _ \| '_ \| '_ ` _ \| | | | __| '_ ` _ \| | | \ \/ /
| |_) | | | | | | | |_) | | | | | | |_| | |_| | | | | | |_| |>  <
| .__/|_|_| |_| |_| .__/|_| |_| |_|\__, |\__|_| |_| |_|\__,_/_/\_\
|_|               |_|              |___/
EOF
    echo -e "${RESET}"
    echo -e "${DIM}Modern, modular tmux configuration${RESET}"
    echo ""

    info "Installing pimpmytmux v${PIMPMYTMUX_VERSION}..."
    echo ""

    # Check dependencies
    info "Checking dependencies..."
    check_dependencies

    # Ask to install optional dependencies
    echo ""
    if confirm "Would you like to install optional dependencies?"; then
        install_optional_dependencies
    fi

    # Backup existing config
    echo ""
    backup_existing

    # Create directories
    echo ""
    info "Creating directories..."
    mkdir -p "$PIMPMYTMUX_INSTALL_DIR"
    mkdir -p "$PIMPMYTMUX_CONFIG_DIR"
    mkdir -p "$PIMPMYTMUX_DATA_DIR"
    mkdir -p "$PIMPMYTMUX_BIN_DIR"
    mkdir -p "${PIMPMYTMUX_DATA_DIR}/sessions"
    mkdir -p "${PIMPMYTMUX_DATA_DIR}/backups"

    # Clone or update repository
    # Priority: local repo > git pull > git clone
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -f "${SCRIPT_DIR}/bin/pimpmytmux" ]]; then
        # Running from local repository - always use local version
        info "Installing from local repository..."
        if [[ "$SCRIPT_DIR" != "$PIMPMYTMUX_INSTALL_DIR" ]]; then
            rm -rf "$PIMPMYTMUX_INSTALL_DIR"
            cp -r "$SCRIPT_DIR" "$PIMPMYTMUX_INSTALL_DIR"
        fi
        success "Installed from local"
    elif [[ -d "${PIMPMYTMUX_INSTALL_DIR}/.git" ]]; then
        # Existing installation - update from remote
        info "Updating pimpmytmux..."
        cd "$PIMPMYTMUX_INSTALL_DIR"
        # Ensure remote is configured and pull from origin main
        if ! git remote get-url origin &>/dev/null; then
            git remote add origin "$PIMPMYTMUX_REPO"
        fi
        git pull origin main --quiet
        success "Updated to latest version"
    else
        # Fresh install - clone from remote
        info "Cloning pimpmytmux repository..."
        git clone --quiet "$PIMPMYTMUX_REPO" "$PIMPMYTMUX_INSTALL_DIR"
        success "Cloned repository"
    fi

    # Create symlink to CLI
    info "Setting up CLI..."
    chmod +x "${PIMPMYTMUX_INSTALL_DIR}/bin/pimpmytmux"
    ln -sf "${PIMPMYTMUX_INSTALL_DIR}/bin/pimpmytmux" "${PIMPMYTMUX_BIN_DIR}/pimpmytmux"
    success "CLI available at ${PIMPMYTMUX_BIN_DIR}/pimpmytmux"

    # Copy example config if not exists
    if [[ ! -f "${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml" ]]; then
        info "Creating default configuration..."
        cp "${PIMPMYTMUX_INSTALL_DIR}/pimpmytmux.yaml.example" "${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml"
        success "Created ${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml"
    else
        info "Keeping existing configuration"
    fi

    # Generate and apply config
    echo ""
    info "Generating tmux configuration..."
    "${PIMPMYTMUX_BIN_DIR}/pimpmytmux" apply || true

    # Add to PATH if needed
    if [[ ":$PATH:" != *":${PIMPMYTMUX_BIN_DIR}:"* ]]; then
        echo ""
        warn "${PIMPMYTMUX_BIN_DIR} is not in your PATH"
        echo ""
        echo "Add it to your shell configuration:"
        echo ""
        echo "  # Bash (~/.bashrc)"
        echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
        echo ""
        echo "  # Zsh (~/.zshrc)"
        echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
        echo ""
        echo "  # Fish (~/.config/fish/config.fish)"
        echo "  fish_add_path \$HOME/.local/bin"
    fi

    # Done!
    echo ""
    echo -e "${GREEN}${BOLD}Installation complete!${RESET}"
    echo ""
    echo "Next steps:"
    echo -e "  1. Start tmux: ${CYAN}tmux${RESET}"
    echo -e "  2. Edit config: ${CYAN}pimpmytmux edit${RESET}"
    echo -e "  3. List themes: ${CYAN}pimpmytmux themes${RESET}"
    echo -e "  4. Apply changes: ${CYAN}pimpmytmux apply${RESET}"
    echo ""
    echo "Configuration: ${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml"
    echo "Documentation: https://github.com/christopherlouet/pimpmytmux"
    echo ""
}

# -----------------------------------------------------------------------------
# Uninstall
# -----------------------------------------------------------------------------

uninstall_pimpmytmux() {
    echo ""
    warn "Uninstalling pimpmytmux..."

    # Remove symlinks
    rm -f "${PIMPMYTMUX_BIN_DIR}/pimpmytmux"
    rm -f "$HOME/.tmux.conf"

    # Remove installation directory
    rm -rf "$PIMPMYTMUX_INSTALL_DIR"

    echo ""
    info "Removed pimpmytmux installation"
    info "Config preserved at: ${PIMPMYTMUX_CONFIG_DIR}"
    info "Data preserved at: ${PIMPMYTMUX_DATA_DIR}"
    echo ""
    echo "To fully remove, also run:"
    echo "  rm -rf ${PIMPMYTMUX_CONFIG_DIR}"
    echo "  rm -rf ${PIMPMYTMUX_DATA_DIR}"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
    case "${1:-install}" in
        install)
            install_pimpmytmux
            ;;
        uninstall|remove)
            uninstall_pimpmytmux
            ;;
        deps|dependencies)
            echo ""
            info "Installing optional dependencies..."
            install_optional_dependencies
            ;;
        --help|-h)
            echo "Usage: $0 [install|uninstall|deps]"
            echo ""
            echo "Commands:"
            echo "  install    Install pimpmytmux (default)"
            echo "  uninstall  Remove pimpmytmux"
            echo "  deps       Install optional dependencies interactively"
            ;;
        *)
            error "Unknown command: $1"
            echo "Usage: $0 [install|uninstall|deps]"
            exit 1
            ;;
    esac
}

main "$@"
