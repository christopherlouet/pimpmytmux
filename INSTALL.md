# Installation Guide

This guide provides step-by-step instructions to install pimpmytmux on your system.

## Table of Contents

- [Requirements](#requirements)
- [Quick Install](#quick-install)
- [Platform-Specific Installation](#platform-specific-installation)
  - [Ubuntu / Debian](#ubuntu--debian)
  - [Fedora / RHEL / CentOS](#fedora--rhel--centos)
  - [Arch Linux](#arch-linux)
  - [macOS](#macos)
  - [WSL2 (Windows Subsystem for Linux)](#wsl2-windows-subsystem-for-linux)
- [Dependencies](#dependencies)
  - [Required](#required)
  - [Recommended](#recommended)
  - [Optional](#optional)
- [Verify Installation](#verify-installation)
- [Updating](#updating)
- [Uninstalling](#uninstalling)
- [Troubleshooting](#troubleshooting)

---

## Requirements

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| tmux | 3.0 | 3.2+ |
| bash | 4.0 | 5.0+ |
| git | 2.0 | latest |

---

## Quick Install

For experienced users, run this one-liner:

```bash
git clone https://github.com/christopherlouet/pimpmytmux.git && cd pimpmytmux && ./install.sh
```

Or with curl:

```bash
curl -fsSL https://raw.githubusercontent.com/christopherlouet/pimpmytmux/main/install.sh | bash
```

The installer will:
1. Check and install required dependencies (tmux, git)
2. Optionally install recommended dependencies (yq, fzf, gum, jq)
3. Backup any existing tmux configuration
4. Install pimpmytmux to `~/.pimpmytmux`
5. Create configuration directory at `~/.config/pimpmytmux`
6. Set up the CLI at `~/.local/bin/pimpmytmux`

---

## Platform-Specific Installation

### Ubuntu / Debian

**Step 1: Install required dependencies**

```bash
sudo apt update
sudo apt install -y tmux git
```

**Step 2: Install recommended dependencies**

```bash
# fzf - fuzzy finder for session/window switching
sudo apt install -y fzf

# yq - YAML parser (Go version, required for full features)
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq

# jq - JSON parser (for session management)
sudo apt install -y jq
```

**Step 3: Install optional dependencies (gum for interactive wizard)**

```bash
# Add Charm repository
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
sudo apt update
sudo apt install -y gum
```

**Step 4: Install pimpmytmux**

```bash
git clone https://github.com/christopherlouet/pimpmytmux.git
cd pimpmytmux
./install.sh
```

The installer will offer to install optional dependencies interactively.

**Step 5: Add to PATH (if not already done)**

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

---

### Fedora / RHEL / CentOS

**Step 1: Install required dependencies**

```bash
sudo dnf install -y tmux git
```

**Step 2: Install recommended dependencies**

```bash
# fzf
sudo dnf install -y fzf

# yq (Go version)
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq

# jq
sudo dnf install -y jq
```

**Step 3: Install optional dependencies**

```bash
# gum - download binary
VERSION="0.13.0"
curl -fsSL "https://github.com/charmbracelet/gum/releases/download/v${VERSION}/gum_${VERSION}_Linux_x86_64.tar.gz" | tar -xzf - -C /tmp
sudo mv /tmp/gum /usr/local/bin/gum
sudo chmod +x /usr/local/bin/gum
```

**Step 4: Install pimpmytmux**

```bash
git clone https://github.com/christopherlouet/pimpmytmux.git
cd pimpmytmux
./install.sh
```

The installer will offer to install optional dependencies interactively.

**Step 5: Add to PATH**

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

---

### Arch Linux

**Step 1: Install all dependencies**

```bash
# Required + recommended
sudo pacman -S tmux git fzf jq

# yq from AUR (using yay)
yay -S yq-bin

# gum from AUR
yay -S gum
```

**Step 2: Install pimpmytmux**

```bash
git clone https://github.com/christopherlouet/pimpmytmux.git
cd pimpmytmux
./install.sh
```

**Step 3: Add to PATH**

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

---

### macOS

**Step 1: Install Homebrew (if not installed)**

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

**Step 2: Install all dependencies**

```bash
brew install tmux git fzf yq gum jq
```

**Step 3: Install pimpmytmux**

```bash
git clone https://github.com/christopherlouet/pimpmytmux.git
cd pimpmytmux
./install.sh
```

**Step 4: Add to PATH (for zsh, default on macOS)**

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

**Note for macOS users:** If you experience clipboard issues, ensure you have `reattach-to-user-namespace` installed:

```bash
brew install reattach-to-user-namespace
```

---

### WSL2 (Windows Subsystem for Linux)

**Step 1: Follow Ubuntu/Debian instructions above**

WSL2 typically uses Ubuntu, so follow the [Ubuntu/Debian](#ubuntu--debian) section.

**Step 2: Configure clipboard integration**

For copy/paste to work with Windows clipboard, add to your `~/.config/pimpmytmux/pimpmytmux.yaml`:

```yaml
platform:
  wsl:
    copy_command: "clip.exe"
```

**Step 3: Configure terminal for true colors**

In Windows Terminal settings, ensure your WSL profile uses a compatible color scheme. Add to your Windows Terminal `settings.json`:

```json
{
  "profiles": {
    "list": [
      {
        "name": "Ubuntu",
        "colorScheme": "One Half Dark"
      }
    ]
  }
}
```

**Step 4: Fix potential tmux issues**

If tmux doesn't display colors correctly:

```bash
# Add to ~/.bashrc
export TERM=xterm-256color
```

---

## Dependencies

### Required

| Dependency | Purpose | Install Command |
|------------|---------|-----------------|
| tmux >= 3.0 | Terminal multiplexer | `apt install tmux` |
| git | Repository cloning | `apt install git` |
| bash >= 4.0 | Script execution | Usually pre-installed |

### Recommended

| Dependency | Purpose | Why You Need It |
|------------|---------|-----------------|
| [yq](https://github.com/mikefarah/yq) | YAML parsing | Enables full YAML configuration support |
| [fzf](https://github.com/junegunn/fzf) | Fuzzy finder | Powers session/window/pane switching |

**Without yq:** Configuration parsing will use a basic fallback. Some features may not work.

**Without fzf:** You lose fuzzy search capabilities (`Ctrl+s` for sessions, `Ctrl+w` for windows).

### Optional

| Dependency | Purpose | When to Install |
|------------|---------|-----------------|
| [gum](https://github.com/charmbracelet/gum) | Interactive UI | If you want to use `pimpmytmux wizard` |
| [jq](https://stedolan.github.io/jq/) | JSON parsing | If you use session save/restore features |
| Nerd Font | Status bar icons | If you want icons in status bar |

### Monitoring Layout Dependencies

These optional tools enhance the monitoring layout (`pimpmytmux layout monitoring`):

| Dependency | Purpose | Install Command |
|------------|---------|-----------------|
| [htop](https://htop.dev/) | Interactive process monitor | `apt install htop` |
| [duf](https://github.com/muesli/duf) | Colorful disk usage | `apt install duf` |
| [ccze](https://github.com/corber/ccze) | Log colorizer | `apt install ccze` |

**Without these tools:** The layout will use fallbacks (top, df, plain logs).

**Nerd Font installation:**

1. Download a font from [Nerd Fonts](https://www.nerdfonts.com/font-downloads) (e.g., FiraCode, JetBrains Mono)
2. Install the font on your system
3. Configure your terminal to use the Nerd Font

---

## Verify Installation

After installation, verify everything is working:

```bash
# Check pimpmytmux is accessible
pimpmytmux --help

# Check current status
pimpmytmux status

# Validate configuration
pimpmytmux check

# List available themes
pimpmytmux themes

# List available layouts
pimpmytmux layouts

# Start tmux with your new config
tmux
```

**Expected output after `pimpmytmux status`:**

```
pimpmytmux status
Version:    v1.0.1
Platform:   linux
tmux:       tmux 3.4
Config:     ~/.config/pimpmytmux/pimpmytmux.yaml
Generated:  ~/.config/pimpmytmux/tmux.conf
Session:    outside tmux

Dependencies:
  + yq
  + fzf
  - gum (optional)
```

---

## Updating

To update pimpmytmux to the latest version:

```bash
cd ~/.pimpmytmux
git pull
pimpmytmux apply
```

Or re-run the installer from the installation directory:

```bash
cd ~/.pimpmytmux
./install.sh
```

---

## Uninstalling

To remove pimpmytmux:

```bash
cd ~/.pimpmytmux
./install.sh uninstall
```

To completely remove all files:

```bash
cd ~/.pimpmytmux
./install.sh uninstall
rm -rf ~/.pimpmytmux
rm -rf ~/.config/pimpmytmux
rm -rf ~/.local/share/pimpmytmux
```

---

## Troubleshooting

### "pimpmytmux: command not found"

Your PATH doesn't include `~/.local/bin`. Add it:

```bash
# Bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Zsh
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# Fish
fish_add_path $HOME/.local/bin
```

### "yq: command not found" or YAML parsing errors

Install yq (Go version, not the Python one):

```bash
# Linux
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq

# macOS
brew install yq

# Verify it's the Go version
yq --version  # Should show "yq (https://github.com/mikefarah/yq/)"
```

### Colors not displaying correctly

1. Check your terminal supports 256 colors:
   ```bash
   echo $TERM
   # Should be xterm-256color, screen-256color, or tmux-256color
   ```

2. Test true color support:
   ```bash
   printf '\e[48;2;255;0;0m  RED  \e[0m\n'
   # Should show a red background
   ```

3. If not working, add to your shell config:
   ```bash
   export TERM=xterm-256color
   ```

### tmux version too old

Check your version:
```bash
tmux -V
```

If below 3.0, install from source or use a PPA:

```bash
# Ubuntu - use a PPA
sudo add-apt-repository ppa:pi-rho/dev
sudo apt update
sudo apt install tmux
```

### Status bar widgets not showing

1. Check cache directory exists:
   ```bash
   mkdir -p ~/.cache/pimpmytmux
   ```

2. Verify monitoring modules are enabled in config:
   ```yaml
   modules:
     monitoring:
       enabled: true
   ```

3. Reload configuration:
   ```bash
   pimpmytmux apply
   # Or inside tmux: prefix + r
   ```

### Keybindings not working

1. Check for conflicts with your existing `.tmux.conf`:
   ```bash
   cat ~/.tmux.conf
   # Should source pimpmytmux config
   ```

2. Ensure the config was applied:
   ```bash
   pimpmytmux apply
   ```

3. Reload tmux (inside tmux session):
   ```bash
   tmux source-file ~/.tmux.conf
   ```

### Session save/restore not working

Ensure jq is installed:
```bash
sudo apt install jq  # Debian/Ubuntu
brew install jq       # macOS
```

---

## Next Steps

Now that pimpmytmux is installed, see the [Usage Guide](USAGE.md) to learn how to:
- Configure your setup
- Use themes and layouts
- Manage sessions
- Customize keybindings

Or run the interactive wizard:

```bash
pimpmytmux wizard
```

Or quick setup with defaults:

```bash
pimpmytmux setup
```
