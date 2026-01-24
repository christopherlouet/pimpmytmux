# pimpmytmux Troubleshooting Guide

Solutions for common problems and error messages.

## Table of Contents

- [Installation Issues](#installation-issues)
- [Configuration Errors](#configuration-errors)
- [Theme Problems](#theme-problems)
- [Session Issues](#session-issues)
- [Module Problems](#module-problems)
- [Performance Issues](#performance-issues)
- [Error Messages](#error-messages)
- [Debug Mode](#debug-mode)

## Installation Issues

### "yq is required but not installed"

pimpmytmux requires yq (Go version) for YAML parsing.

**Solution:**

```bash
# Ubuntu/Debian
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq

# macOS
brew install yq

# Snap
sudo snap install yq
```

**Note:** The Python version of yq (via pip) has different syntax. Use the Go version from mikefarah/yq.

### "Command not found: pimpmytmux"

The pimpmytmux binary is not in your PATH.

**Solution:**

```bash
# Option 1: Add to PATH
echo 'export PATH="$HOME/.config/pimpmytmux/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Option 2: Create symlink
sudo ln -sf ~/.config/pimpmytmux/bin/pimpmytmux /usr/local/bin/pimpmytmux

# Option 3: Use full path
~/.config/pimpmytmux/bin/pimpmytmux apply
```

### "tmux: command not found"

tmux is not installed.

**Solution:**

```bash
# Ubuntu/Debian
sudo apt install tmux

# macOS
brew install tmux

# Fedora
sudo dnf install tmux

# Arch
sudo pacman -S tmux
```

### tmux version too old

pimpmytmux requires tmux 3.0+.

**Check version:**
```bash
tmux -V
```

**Upgrade:**
```bash
# Ubuntu (via backports or compile from source)
sudo apt install tmux

# macOS
brew upgrade tmux
```

## Configuration Errors

### "Invalid YAML syntax"

Your configuration file has syntax errors.

**Diagnose:**
```bash
# Check with yq
yq eval '.' ~/.config/pimpmytmux/pimpmytmux.yaml

# Or use pimpmytmux check
pimpmytmux check
```

**Common YAML mistakes:**

```yaml
# Wrong - missing space after colon
theme:matrix

# Correct
theme: matrix

# Wrong - inconsistent indentation
modules:
  sessions:
   enabled: true  # Wrong indent

# Correct
modules:
  sessions:
    enabled: true  # 2-space indent

# Wrong - unquoted special characters
status_bar:
  left: #S | #I:#W  # # starts a comment

# Correct
status_bar:
  left: " #S | #I:#W "  # Quoted string
```

### "Configuration validation failed"

The generated tmux config has syntax errors.

**Solution:**
```bash
# Check what's wrong
pimpmytmux apply --dry-run

# Look for tmux-specific errors
tmux source-file ~/.config/pimpmytmux/tmux.conf
```

**Common issues:**
- Invalid color codes
- Unknown tmux options (check tmux version)
- Malformed keybinding syntax

### "Theme not found"

The specified theme doesn't exist.

**Solution:**
```bash
# List available themes
pimpmytmux themes

# Check theme file exists
ls ~/.config/pimpmytmux/themes/
```

### "Config file not found"

The config file doesn't exist.

**Solution:**
```bash
# Initialize config
pimpmytmux init

# Or run setup
pimpmytmux setup
```

## Theme Problems

### Colors not displaying correctly

**Symptoms:**
- Status bar shows wrong colors
- Pane borders are colorless
- Theme looks "washed out"

**Cause:** Terminal doesn't support true color (24-bit).

**Test true color:**
```bash
printf '\e[48;2;255;0;0m  RED  \e[0m\n'
printf '\e[48;2;0;255;0m GREEN \e[0m\n'
printf '\e[48;2;0;0;255m BLUE  \e[0m\n'
```

If you see solid color blocks, true color works.

**Fixes:**

1. Set correct TERM:
```bash
# Add to ~/.bashrc or ~/.zshrc
export TERM=xterm-256color
```

2. Enable true color in tmux config:
```yaml
general:
  true_color: true
  default_terminal: "tmux-256color"
```

3. Use a true color capable terminal:
   - iTerm2 (macOS)
   - Alacritty
   - Kitty
   - Windows Terminal
   - GNOME Terminal

### Status bar icons not showing

**Cause:** Missing Nerd Font.

**Solution:**

Install a Nerd Font:
```bash
# macOS
brew tap homebrew/cask-fonts
brew install --cask font-hack-nerd-font

# Linux
mkdir -p ~/.local/share/fonts
cd ~/.local/share/fonts
curl -fLo "Hack Regular Nerd Font Complete.ttf" \
  https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/Hack/Regular/HackNerdFont-Regular.ttf
fc-cache -fv
```

Then set your terminal to use the Nerd Font.

### Theme changes not applying

**Solution:**
```bash
# Regenerate and reload
pimpmytmux apply

# If inside tmux
pimpmytmux reload

# Or manual reload
tmux source-file ~/.config/pimpmytmux/tmux.conf
```

## Session Issues

### "Must be inside tmux" error

Session commands require running inside tmux.

**Solution:**
```bash
# Start tmux first
tmux

# Then run command
pimpmytmux session save mywork
```

### Session restore not working

**Check saved sessions:**
```bash
pimpmytmux session list
ls ~/.local/share/pimpmytmux/sessions/
```

**Common issues:**
- Session file corrupted
- tmux not running
- Different tmux version

### Sessions not auto-saving

**Check config:**
```yaml
modules:
  sessions:
    enabled: true
    auto_save: true
```

**Check tmux is running:**
```bash
tmux list-sessions
```

## Module Problems

### fzf integration not working

**Check fzf is installed:**
```bash
which fzf
fzf --version
```

**Check config:**
```yaml
modules:
  navigation:
    enabled: true
    fzf_integration: true
```

**Regenerate config:**
```bash
pimpmytmux apply
```

### Vim-style navigation not working

**Check config:**
```yaml
modules:
  navigation:
    enabled: true
    vim_mode: true
```

**Verify keybindings:**
```bash
# Inside tmux
tmux list-keys | grep "select-pane"
```

### Monitoring widgets not updating

**Check cache:**
```bash
ls -la ~/.cache/pimpmytmux/
```

**Clear cache:**
```bash
rm -rf ~/.cache/pimpmytmux/*
pimpmytmux reload
```

**Check interval:**
```yaml
status_bar:
  interval: 5  # Update every 5 seconds
```

## Performance Issues

### tmux is slow/laggy

**Reduce status bar updates:**
```yaml
status_bar:
  interval: 10  # Less frequent updates
```

**Disable heavy widgets:**
```yaml
modules:
  monitoring:
    enabled: true
    cpu: false      # Disable if not needed
    memory: false
```

**Check for heavy scripts:**
```bash
# View status-right command
tmux show-options -g status-right
```

### High CPU usage

**Possible causes:**
- Status bar scripts running too frequently
- Large scrollback buffer

**Solutions:**
```yaml
general:
  history_limit: 10000  # Reduce from 50000

status_bar:
  interval: 15  # Less frequent updates
```

### Slow startup

**Diagnose:**
```bash
time pimpmytmux apply

# Check config generation time
pimpmytmux apply --dry-run 2>&1 | head -20
```

## Error Messages

### "Permission denied"

**Cause:** File permissions issue.

**Solution:**
```bash
chmod +x ~/.config/pimpmytmux/bin/pimpmytmux
chmod 644 ~/.config/pimpmytmux/pimpmytmux.yaml
```

### "No backups available"

**Cause:** No backup files exist yet.

**Solution:**
```bash
# Create a backup manually
pimpmytmux backup create

# Or apply config (creates backup automatically)
pimpmytmux apply
```

### "Unknown command"

**Cause:** Typo or command doesn't exist.

**Solution:**
```bash
# List available commands
pimpmytmux help
```

### "Unknown option"

**Cause:** Invalid command-line option.

**Solution:**
```bash
# Check valid options
pimpmytmux --help
```

## Debug Mode

### Enable verbose logging

```bash
# Verbose mode
pimpmytmux -v apply

# Debug mode (most verbose)
pimpmytmux -d apply

# Or set environment variable
export PIMPMYTMUX_VERBOSITY=3
pimpmytmux apply
```

### Check generated config

```bash
# Preview without applying
pimpmytmux apply --dry-run

# View current config
cat ~/.config/pimpmytmux/tmux.conf
```

### Validate step by step

```bash
# 1. Check YAML syntax
yq eval '.' ~/.config/pimpmytmux/pimpmytmux.yaml

# 2. Validate config
pimpmytmux check

# 3. Generate only
pimpmytmux apply --dry-run

# 4. Test tmux config
tmux source-file ~/.config/pimpmytmux/tmux.conf
```

### View tmux errors

```bash
# Check tmux server log
tmux show-messages

# Or run tmux with verbose logging
tmux -v
```

## Getting Help

### Check status

```bash
pimpmytmux status
```

This shows:
- Version info
- Platform
- tmux version
- Config file locations
- Dependencies status

### Report issues

When reporting issues, include:

1. Output of `pimpmytmux status`
2. Output of `pimpmytmux check`
3. Your config file (without sensitive data)
4. Error messages
5. tmux version (`tmux -V`)
6. OS and version

### Community

- GitHub Issues: https://github.com/christopherlouet/pimpmytmux/issues
- Discussions: https://github.com/christopherlouet/pimpmytmux/discussions
