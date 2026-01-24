# pimpmytmux Usage Guide

Complete guide for configuring and using pimpmytmux.

## Table of Contents

- [Quick Reference](#quick-reference)
- [Configuration](#configuration)
- [Commands](#commands)
- [Workflows](#workflows)
- [Themes](#themes)
- [Layouts](#layouts)
- [Keybindings](#keybindings)
- [Modules](#modules)
- [Backup and Restore](#backup-and-restore)
- [FAQ](#faq)

## Quick Reference

```bash
# Essential commands
pimpmytmux apply              # Apply configuration
pimpmytmux reload             # Reload (inside tmux)
pimpmytmux theme <name>       # Switch theme
pimpmytmux layout <name>      # Apply layout
pimpmytmux zen                # Toggle zen mode

# Session management
pimpmytmux session save <name>
pimpmytmux session restore <name>
pimpmytmux session list

# Backup management
pimpmytmux backup list
pimpmytmux backup restore
pimpmytmux backup create

# Utilities
pimpmytmux check              # Validate config
pimpmytmux status             # Show status
pimpmytmux edit               # Edit config
```

## Configuration

Configuration file location: `~/.config/pimpmytmux/pimpmytmux.yaml`

### Complete Configuration Example

```yaml
# Theme selection
theme: cyberpunk  # cyberpunk, matrix, dracula, catppuccin, nord, gruvbox, tokyo-night

# General settings
general:
  prefix: C-b           # Prefix key: C-b, C-a, C-Space
  prefix2: ""           # Secondary prefix (optional)
  base_index: 1         # Start window/pane numbering from 1
  mouse: true           # Enable mouse support
  history_limit: 50000  # Scrollback buffer size
  escape_time: 10       # Reduce delay after Escape key (ms)
  focus_events: true    # Enable focus events for vim autoread
  true_color: true      # Enable 24-bit color support
  default_terminal: "tmux-256color"

# Window settings
windows:
  renumber: true        # Renumber windows when one is closed
  auto_rename: true     # Automatic window renaming

# Pane settings
panes:
  retain_path: true     # New panes inherit current path
  display_time: 2000    # Pane indicator display time (ms)

# Keybindings
keybindings:
  reload: r             # Reload config
  split_horizontal: "|" # Horizontal split
  split_vertical: "-"   # Vertical split
  zoom_pane: z          # Zoom/unzoom pane
  close_pane: x         # Close pane

# Status bar
status_bar:
  position: bottom      # top or bottom
  interval: 5           # Update interval (seconds)
  left: " #S | #I:#W "  # Left content
  right: " %H:%M %d-%b " # Right content
  left_length: 40       # Max left length
  right_length: 80      # Max right length

# Modules
modules:
  # Session management
  sessions:
    enabled: true
    auto_save: false      # Save on tmux exit
    auto_restore: false   # Restore on tmux start
    save_interval: 300    # Auto-save interval (seconds)

  # Navigation enhancements
  navigation:
    enabled: true
    vim_mode: true        # hjkl pane navigation
    fzf_integration: true # fzf session/window switcher
    smart_splits: true    # Intelligent split sizing

  # Development tools
  devtools:
    enabled: true
    git_status: true      # Show git branch in status
    project_detection: true

  # System monitoring widgets
  monitoring:
    enabled: true
    cpu: true             # CPU usage
    memory: true          # Memory usage
    battery: true         # Battery status (laptops)
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PIMPMYTMUX_CONFIG_DIR` | `~/.config/pimpmytmux` | Configuration directory |
| `PIMPMYTMUX_DATA_DIR` | `~/.local/share/pimpmytmux` | Data directory |
| `PIMPMYTMUX_CACHE_DIR` | `~/.cache/pimpmytmux` | Cache directory |
| `PIMPMYTMUX_VERBOSITY` | `1` | Log level (0=quiet, 1=normal, 2=verbose, 3=debug) |

## Commands

### apply

Generate and apply tmux configuration.

```bash
pimpmytmux apply              # Apply with validation and backup
pimpmytmux apply --no-backup  # Apply without backup
pimpmytmux apply --dry-run    # Preview generated config
```

**What it does:**
1. Validates your YAML configuration
2. Generates `tmux.conf` from your settings
3. Creates a backup of existing config
4. Validates the generated tmux config
5. Applies the configuration

### reload

Reload configuration while inside tmux.

```bash
pimpmytmux reload
```

**Note:** Must be run from inside a tmux session.

### theme

Switch to a different theme.

```bash
pimpmytmux theme cyberpunk
pimpmytmux theme matrix
pimpmytmux theme dracula
```

This updates your config and regenerates the tmux configuration.

### themes

List all available themes.

```bash
pimpmytmux themes
```

### session

Manage tmux sessions.

```bash
# Save current session
pimpmytmux session save myproject

# Restore a saved session
pimpmytmux session restore myproject

# List saved sessions
pimpmytmux session list
```

**Session data saved:**
- Windows and their names
- Pane layout
- Working directories
- Current window/pane

### layout

Apply a predefined pane layout.

```bash
pimpmytmux layout dev-fullstack
pimpmytmux layout monitoring
pimpmytmux layout dev-api
pimpmytmux layout writing
```

**Note:** Some layouts may close existing panes. You'll be prompted for confirmation.

### layouts

List available layouts.

```bash
pimpmytmux layouts
```

### zen

Toggle distraction-free mode.

```bash
pimpmytmux zen          # Toggle
pimpmytmux zen on       # Enable
pimpmytmux zen off      # Disable
```

**Zen mode:**
- Hides the status bar
- Hides pane borders
- Doesn't affect pane layout

### backup

Manage configuration backups.

```bash
pimpmytmux backup list           # List all backups
pimpmytmux backup restore        # Restore latest backup
pimpmytmux backup restore <file> # Restore specific backup
pimpmytmux backup create         # Create manual backup
pimpmytmux backup cleanup 5      # Keep only last 5 backups
```

### check

Validate your configuration.

```bash
pimpmytmux check
```

**Validates:**
- YAML syntax
- Theme existence
- tmux config syntax
- Required settings

### status

Show current pimpmytmux status.

```bash
pimpmytmux status
```

**Shows:**
- Version
- Platform
- tmux version
- Config file location
- Dependencies status

### edit

Open configuration file in your editor.

```bash
pimpmytmux edit
```

Uses `$EDITOR` or falls back to `vim`.

### wizard

Run interactive setup wizard.

```bash
pimpmytmux wizard
```

Guides you through configuration with visual menus.

### setup

Quick setup with sensible defaults.

```bash
pimpmytmux setup
```

## Workflows

### Initial Setup

```bash
# Clone and install
git clone https://github.com/christopherlouet/pimpmytmux.git ~/.config/pimpmytmux
cd ~/.config/pimpmytmux
./install.sh

# Run wizard for guided setup
pimpmytmux wizard

# Or use quick setup
pimpmytmux setup
```

### Daily Usage

```bash
# Start tmux
tmux

# Inside tmux, switch themes anytime
pimpmytmux theme matrix

# Apply a layout for your workflow
pimpmytmux layout dev-fullstack

# Save your session before leaving
pimpmytmux session save work
```

### After Editing Config

```bash
# Edit configuration
pimpmytmux edit

# Validate changes
pimpmytmux check

# Apply changes
pimpmytmux apply

# Or if inside tmux
pimpmytmux reload
```

### Recovering from Mistakes

```bash
# List available backups
pimpmytmux backup list

# Restore previous config
pimpmytmux backup restore

# Re-apply
pimpmytmux apply
```

## Themes

### Available Themes

| Theme | Description |
|-------|-------------|
| `cyberpunk` | Neon pink and cyan, default theme |
| `matrix` | Green on black, hacker aesthetic |
| `dracula` | Dark theme with purple accents |
| `catppuccin` | Soft pastel colors |
| `nord` | Cool blue Arctic tones |
| `gruvbox` | Retro warm colors |
| `tokyo-night` | Tokyo city lights inspired |

### Theme Colors

Each theme defines:
- Background and foreground colors
- Accent colors for highlights
- Status bar colors
- Active/inactive pane colors
- Message and prompt colors

### Creating Custom Themes

Create a new file in `themes/` directory:

```yaml
# themes/mytheme.yaml
name: mytheme
description: My custom theme

colors:
  bg: "#1a1b26"
  fg: "#c0caf5"
  accent: "#7aa2f7"
  accent2: "#bb9af7"

status:
  bg: "#1a1b26"
  fg: "#c0caf5"
  left_bg: "#7aa2f7"
  left_fg: "#1a1b26"
  right_bg: "#bb9af7"
  right_fg: "#1a1b26"

pane:
  active_border: "#7aa2f7"
  inactive_border: "#3b4261"

window:
  active_bg: "#7aa2f7"
  active_fg: "#1a1b26"
  inactive_bg: "#3b4261"
  inactive_fg: "#c0caf5"
```

Apply with:
```bash
pimpmytmux theme mytheme
```

## Layouts

### dev-fullstack

60/40 split with editor and terminal/server.

```
┌────────────────────┬───────────────────┐
│                    │    Terminal       │
│      Editor        ├───────────────────┤
│                    │    Server         │
└────────────────────┴───────────────────┘
```

### dev-api

70/30 split for API development.

```
┌────────────────────────────┬───────────┐
│                            │           │
│          Code              │   Logs    │
│                            │           │
└────────────────────────────┴───────────┘
```

### monitoring

4-pane grid for system monitoring.

```
┌───────────────────┬───────────────────┐
│      btop         │   disk / memory   │
├───────────────────┼───────────────────┤
│      logs         │     network       │
└───────────────────┴───────────────────┘
```

### writing

Single maximized pane with zen mode.

**Note:** This layout closes other panes after confirmation.

### Creating Custom Layouts

Create a new file in `templates/` directory:

```yaml
# templates/mylayout.yaml
name: mylayout
description: My custom layout

settings:
  zen_mode: false

panes:
  - name: main
    command: ""
    size: 70%

  - name: sidebar
    command: ""
    size: 30%
    split: horizontal
```

## Keybindings

### Default Prefix: `C-b` (Ctrl+b)

All keybindings require pressing the prefix first.

### Pane Navigation (Vim-style)

| Key | Action |
|-----|--------|
| `h` | Move left |
| `j` | Move down |
| `k` | Move up |
| `l` | Move right |

### Pane Resizing

| Key | Action |
|-----|--------|
| `H` | Resize left |
| `J` | Resize down |
| `K` | Resize up |
| `L` | Resize right |

### Pane Management

| Key | Action |
|-----|--------|
| `\|` | Split horizontally |
| `-` | Split vertically |
| `z` | Zoom/unzoom pane |
| `x` | Close pane |

### Window Management

| Key | Action |
|-----|--------|
| `c` | New window |
| `n` | Next window |
| `p` | Previous window |
| `1-9` | Jump to window |
| `w` | Window list |

### fzf Integration

| Key | Action |
|-----|--------|
| `C-s` | fzf session switcher |
| `C-w` | fzf window switcher |

### Copy Mode (Vi-style)

| Key | Action |
|-----|--------|
| `[` | Enter copy mode |
| `v` | Begin selection |
| `y` | Copy selection |
| `Escape` | Cancel |

### Other

| Key | Action |
|-----|--------|
| `r` | Reload config |
| `?` | List keybindings |

## Modules

### sessions

Session persistence and restoration.

```yaml
modules:
  sessions:
    enabled: true
    auto_save: false      # Save on exit
    auto_restore: false   # Restore on start
```

### navigation

Enhanced pane navigation.

```yaml
modules:
  navigation:
    enabled: true
    vim_mode: true        # hjkl navigation
    fzf_integration: true # Fuzzy finder
    smart_splits: true    # Intelligent sizing
```

### devtools

Development productivity tools.

```yaml
modules:
  devtools:
    enabled: true
    git_status: true      # Git branch in status
    project_detection: true
```

### monitoring

System status widgets in status bar.

```yaml
modules:
  monitoring:
    enabled: true
    cpu: true
    memory: true
    battery: true
```

## Backup and Restore

pimpmytmux automatically backs up your configuration before applying changes.

### Backup Location

`~/.local/share/pimpmytmux/backups/`

### Backup Naming

`pimpmytmux.yaml.YYYYMMDD_HHMMSS.bak`

### Managing Backups

```bash
# View backups
pimpmytmux backup list

# Restore latest
pimpmytmux backup restore

# Restore specific backup
pimpmytmux backup restore ~/.local/share/pimpmytmux/backups/pimpmytmux.yaml.20240101_120000.bak

# Cleanup old backups (keep last 5)
pimpmytmux backup cleanup 5
```

### Disable Auto-Backup

```bash
pimpmytmux apply --no-backup
```

## FAQ

### How do I change the prefix key?

Edit your config:
```yaml
general:
  prefix: C-a  # Use Ctrl+a instead of Ctrl+b
```

Then apply: `pimpmytmux apply`

### Why doesn't my theme show colors correctly?

Ensure your terminal supports true color:
```bash
# Test
printf '\e[48;2;255;0;0m  RED  \e[0m\n'

# If it shows a red block, true color works
```

Add to your shell config:
```bash
export TERM=xterm-256color
```

### Can I use pimpmytmux with my existing tmux.conf?

pimpmytmux generates its own `tmux.conf`. To use both:

1. Let pimpmytmux generate its config
2. Add custom settings at the end of the generated file
3. Or use `source-file` in pimpmytmux config to include your file

### How do I reset to defaults?

```bash
# Remove config
rm ~/.config/pimpmytmux/pimpmytmux.yaml

# Re-run setup
pimpmytmux setup
```

### Where are sessions saved?

`~/.local/share/pimpmytmux/sessions/`

### Can I have different configs for different machines?

Use environment variables:
```bash
export PIMPMYTMUX_CONFIG_DIR=~/.config/pimpmytmux-work
pimpmytmux apply
```

### How do I update pimpmytmux?

```bash
cd ~/.config/pimpmytmux
git pull
pimpmytmux apply
```
