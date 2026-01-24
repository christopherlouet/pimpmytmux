# Usage Guide

Complete guide to using and configuring pimpmytmux.

## Table of Contents

- [Getting Started](#getting-started)
  - [First Launch](#first-launch)
  - [Interactive Wizard](#interactive-wizard)
  - [Quick Setup](#quick-setup)
- [Commands Reference](#commands-reference)
- [Configuration](#configuration)
  - [Configuration File](#configuration-file)
  - [General Settings](#general-settings)
  - [Status Bar](#status-bar)
  - [Modules](#modules)
  - [Keybindings](#keybindings)
  - [Conditional Keybindings](#conditional-keybindings)
- [Themes](#themes)
  - [Available Themes](#available-themes)
  - [Switching Themes](#switching-themes)
  - [Creating Custom Themes](#creating-custom-themes)
- [Layouts](#layouts)
  - [Available Layouts](#available-layouts)
  - [Using Layouts](#using-layouts)
- [Zen Mode](#zen-mode)
- [Session Management](#session-management)
  - [Saving Sessions](#saving-sessions)
  - [Restoring Sessions](#restoring-sessions)
  - [Auto Save/Restore](#auto-saverestore)
- [Session Templates](#session-templates)
- [Profiles](#profiles)
- [Project Detection](#project-detection)
- [Git Sync](#git-sync)
- [Plugins](#plugins)
- [Backup and Migration](#backup-and-migration)
- [Keybindings](#keybindings-1)
  - [Default Keybindings](#default-keybindings)
  - [Vim Mode](#vim-mode)
  - [fzf Integration](#fzf-integration)
- [Configuration Examples](#configuration-examples)
  - [Minimal Setup](#minimal-setup)
  - [Vim Power User](#vim-power-user)
  - [DevOps/Monitoring Setup](#devopsmonitoring-setup)
  - [Writer/Distraction-Free](#writerdistraction-free)
- [Workflows](#workflows)
  - [Development Workflow](#development-workflow)
  - [DevOps Workflow](#devops-workflow)
  - [Writing Workflow](#writing-workflow)
- [Tips and Tricks](#tips-and-tricks)
- [FAQ](#faq)

---

## Getting Started

### First Launch

After installation, start tmux:

```bash
tmux
```

Your pimpmytmux configuration should be applied automatically with the default Cyberpunk theme.

### Interactive Wizard

For a guided setup experience, run the wizard:

```bash
pimpmytmux wizard
```

The wizard will ask you about:
1. Preferred theme
2. Prefix key (Ctrl+b or Ctrl+a)
3. Vim mode navigation
4. Which modules to enable
5. Mouse support

### Quick Setup

For a fast setup with sensible defaults:

```bash
# Initialize with defaults
pimpmytmux setup

# Or choose a theme directly
pimpmytmux init
pimpmytmux theme dracula
pimpmytmux apply
```

---

## Commands Reference

### Core Commands

| Command | Description |
|---------|-------------|
| `pimpmytmux apply` | Generate and apply tmux configuration |
| `pimpmytmux reload` | Reload configuration (inside tmux) |
| `pimpmytmux edit` | Open configuration file in $EDITOR |
| `pimpmytmux check` | Validate configuration file |
| `pimpmytmux status` | Show current status and config |
| `pimpmytmux wizard` | Run interactive setup wizard |
| `pimpmytmux setup` | Quick setup with defaults |
| `pimpmytmux init` | Initialize configuration |

### Themes and Layouts

| Command | Description |
|---------|-------------|
| `pimpmytmux theme <name>` | Switch to a different theme |
| `pimpmytmux theme <name> --preview` | Preview theme before applying |
| `pimpmytmux themes` | List all available themes |
| `pimpmytmux themes --gallery` | Visual theme browser with swatches |
| `pimpmytmux layout <name>` | Apply a predefined layout |
| `pimpmytmux layout <name> --preview` | Preview layout with ASCII diagram |
| `pimpmytmux layouts` | List all available layouts |
| `pimpmytmux zen [on\|off]` | Toggle zen mode (hide status bar + borders) |

### Session Management

| Command | Description |
|---------|-------------|
| `pimpmytmux session save <name>` | Save current session |
| `pimpmytmux session restore <name>` | Restore a saved session |
| `pimpmytmux session list` | List all saved sessions |
| `pimpmytmux template list` | List session templates |
| `pimpmytmux template apply <name>` | Create session from template |
| `pimpmytmux template save <name>` | Save current session as template |

### Profiles

| Command | Description |
|---------|-------------|
| `pimpmytmux profile list` | List available profiles |
| `pimpmytmux profile switch <name>` | Switch to a profile |
| `pimpmytmux profile create <name>` | Create new profile |
| `pimpmytmux profile delete <name>` | Delete a profile |

### Sync and Backup

| Command | Description |
|---------|-------------|
| `pimpmytmux sync init <repo>` | Initialize git sync |
| `pimpmytmux sync push [message]` | Push config to remote |
| `pimpmytmux sync pull` | Pull config from remote |
| `pimpmytmux sync status` | Show sync status |
| `pimpmytmux backup list` | List available backups |
| `pimpmytmux backup restore <name>` | Restore a backup |
| `pimpmytmux backup create` | Create manual backup |
| `pimpmytmux backup cleanup [n]` | Keep only n most recent backups |

### Plugins

| Command | Description |
|---------|-------------|
| `pimpmytmux plugin list` | List installed plugins |
| `pimpmytmux plugin install <url>` | Install plugin from git URL |
| `pimpmytmux plugin remove <name>` | Remove a plugin |
| `pimpmytmux plugin update` | Update all plugins |
| `pimpmytmux plugin enable <name>` | Enable a plugin |
| `pimpmytmux plugin disable <name>` | Disable a plugin |

### Utilities

| Command | Description |
|---------|-------------|
| `pimpmytmux detect` | Detect project type |
| `pimpmytmux detect --apply` | Auto-apply recommended layout |
| `pimpmytmux migrate` | Migrate config to latest version |
| `pimpmytmux migrate --status` | Show migration status |

---

## Configuration

### Configuration File

Your configuration is stored in:
```
~/.config/pimpmytmux/pimpmytmux.yaml
```

Edit with:
```bash
pimpmytmux edit
# Or directly
$EDITOR ~/.config/pimpmytmux/pimpmytmux.yaml
```

After editing, apply changes:
```bash
pimpmytmux apply
```

### General Settings

```yaml
general:
  # Prefix key - the key combo to trigger tmux commands
  # Popular choices: C-b (default), C-a (screen-like), C-Space
  prefix: C-b

  # Start window/pane numbering from 1 (easier to reach on keyboard)
  base_index: 1

  # Enable mouse support (scrolling, clicking panes, resizing)
  mouse: true

  # Scrollback buffer size (number of lines)
  history_limit: 50000

  # Escape delay in ms (lower = faster vim response)
  escape_time: 10

  # Enable 24-bit true color support
  true_color: true
```

### Status Bar

```yaml
status_bar:
  # Position: top or bottom
  position: bottom

  # Update interval in seconds
  interval: 5

  # Left side content
  left: " #{session_icon} #S | #{window_icon} #I:#W "

  # Right side content
  right: "#{prefix}#{mouse} #{git_branch} | #{cpu} #{memory} | %H:%M "

  # Maximum lengths
  left_length: 40
  right_length: 80
```

**Available variables:**
- `#{session}` - Session name
- `#{window}` - Window name
- `#{pane}` - Pane index
- `#{prefix}` - Shows indicator when prefix is pressed
- `#{mouse}` - Shows indicator when mouse mode is on

**Available modules:**
- `#{git_branch}` - Current git branch
- `#{git_status}` - Git status indicators
- `#{cpu}` - CPU usage percentage
- `#{memory}` - Memory usage
- `#{battery}` - Battery level
- `#{network}` - Network status
- `#{weather}` - Weather info
- `#{time}` - Current time

### Modules

```yaml
modules:
  # Session management
  sessions:
    enabled: true
    auto_save: true      # Save on exit
    auto_restore: true   # Restore on start
    save_interval: 15    # Save every 15 minutes

  # Navigation
  navigation:
    enabled: true
    vim_mode: true       # Use hjkl for pane navigation
    fzf_integration: true # Use fzf for switching
    smart_splits: true   # Smart pane splits

  # Developer tools
  devtools:
    enabled: true
    git_status: true     # Show git in status bar
    ide_splits: true     # IDE-like layouts
    project_detection: false

  # Monitoring widgets
  monitoring:
    enabled: true
    components:
      - cpu
      - memory
      - battery
```

### Keybindings

```yaml
keybindings:
  # Presets: default, vim-heavy, minimal
  preset: default

  # Common bindings
  reload: r              # prefix + r to reload config
  split_horizontal: "|"  # prefix + | for horizontal split
  split_vertical: "-"    # prefix + - for vertical split
  zoom_pane: z           # prefix + z to zoom pane
  close_pane: x          # prefix + x to close pane
```

### Conditional Keybindings

Define keybindings that only apply in specific contexts:

```yaml
keybindings:
  conditional:
    # Different bindings per hostname
    - condition: "hostname:work-*"
      bindings:
        prefix: C-a
        split_horizontal: "v"

    # Different bindings per project type
    - condition: "project:node"
      bindings:
        F5: "run-shell 'npm test'"
        F6: "run-shell 'npm start'"

    - condition: "project:rust"
      bindings:
        F5: "run-shell 'cargo test'"
        F6: "run-shell 'cargo run'"

    # Different bindings based on environment
    - condition: "env:SSH_CONNECTION"
      bindings:
        prefix: C-a  # Use C-a when SSH'd
```

**Condition types:**
- `hostname:<pattern>` - Match hostname with wildcards
- `project:<type>` - Match detected project type (node, rust, go, python, etc.)
- `env:<VAR>` or `env:<VAR>=<value>` - Match environment variables

---

## Themes

### Available Themes

| Theme | Description |
|-------|-------------|
| `cyberpunk` | Neon pink and cyan, futuristic aesthetics (default) |
| `matrix` | Green on black, classic hacker look |
| `dracula` | Popular dark theme with purple accents |
| `catppuccin` | Soft pastel colors, easy on the eyes |
| `nord` | Cool blue tones from the Arctic |
| `gruvbox` | Retro warm colors with excellent contrast |
| `tokyo-night` | Dark theme inspired by Tokyo city lights |

### Switching Themes

```bash
# List available themes
pimpmytmux themes

# Switch to a theme
pimpmytmux theme dracula

# Applied immediately if in tmux
```

### Creating Custom Themes

Create a new file in `~/.pimpmytmux/themes/mytheme.yaml`:

```yaml
name: mytheme
description: My custom theme

colors:
  # Background colors
  bg: "#1a1b26"
  bg_dark: "#16161e"
  bg_highlight: "#292e42"

  # Foreground colors
  fg: "#c0caf5"
  fg_dark: "#a9b1d6"
  fg_gutter: "#3b4261"

  # Accent colors
  primary: "#7aa2f7"
  secondary: "#bb9af7"
  accent: "#7dcfff"

  # Status colors
  success: "#9ece6a"
  warning: "#e0af68"
  error: "#f7768e"
  info: "#7dcfff"

  # Status bar
  status_bg: "#16161e"
  status_fg: "#c0caf5"

  # Window tabs
  window_active_bg: "#7aa2f7"
  window_active_fg: "#16161e"
  window_inactive_bg: "#292e42"
  window_inactive_fg: "#a9b1d6"

  # Pane borders
  pane_border: "#3b4261"
  pane_active_border: "#7aa2f7"
```

Apply your theme:
```bash
pimpmytmux theme mytheme
```

---

## Layouts

### Available Layouts

| Layout | Description | Use Case |
|--------|-------------|----------|
| `dev-fullstack` | Editor (60%) + Terminal + Server | Full-stack development |
| `dev-api` | Code (70%) + Logs (30%) | API development |
| `monitoring` | 4-pane grid (htop, duf, logs, network) | System monitoring |
| `writing` | Single pane + zen mode (closes other panes) | Distraction-free writing |

**Monitoring layout optional dependencies:**

For the best experience with the monitoring layout, install these tools:

```bash
# Ubuntu/Debian
sudo apt install htop duf ccze

# Fedora
sudo dnf install htop duf ccze

# Arch
sudo pacman -S htop duf ccze

# macOS
brew install htop duf ccze
```

| Tool | Pane | Fallback |
|------|------|----------|
| htop | Top-left (processes) | top |
| duf | Top-right (disk usage with colors) | df -h |
| ccze | Bottom-left (colorized logs) | plain journalctl |

### Using Layouts

```bash
# List available layouts
pimpmytmux layouts

# Apply a layout
pimpmytmux layout dev-fullstack
pimpmytmux layout monitoring
```

**Note:** The `writing` layout will ask for confirmation before closing existing panes.

**Layout visualizations:**

```
dev-fullstack:
┌────────────────────┬───────────────────┐
│                    │    Terminal       │
│      Editor        ├───────────────────┤
│                    │    Server         │
└────────────────────┴───────────────────┘

dev-api:
┌────────────────────────────┬───────────┐
│                            │           │
│          Code              │   Logs    │
│                            │           │
└────────────────────────────┴───────────┘

monitoring:
┌───────────────────┬───────────────────┐
│      htop         │   disk / memory   │
├───────────────────┼───────────────────┤
│      logs         │     network       │
└───────────────────┴───────────────────┘
```

---

## Zen Mode

Zen mode provides a distraction-free experience by hiding the status bar and pane borders.
Unlike layouts, zen mode **only changes visual settings** without affecting your panes.

### Using Zen Mode

```bash
# Toggle zen mode on/off
pimpmytmux zen

# Explicitly enable or disable
pimpmytmux zen on
pimpmytmux zen off
```

### Combining Zen Mode with Layouts

You can use zen mode with any layout:

```bash
# Apply monitoring layout
pimpmytmux layout monitoring

# Enable zen mode on the 4-pane layout
pimpmytmux zen on

# Disable zen mode to restore status bar
pimpmytmux zen off
```

### Zen Mode vs Writing Layout

| Feature | `pimpmytmux zen` | `pimpmytmux layout writing` |
|---------|------------------|----------------------------|
| Hides status bar | Yes | Yes |
| Hides pane borders | Yes | Yes |
| Closes other panes | **No** | Yes (with confirmation) |
| Affects pane layout | No | Yes |

Use `zen` when you want to temporarily hide UI elements on any layout.
Use `layout writing` when you want a single-pane focused environment.

---

## Session Management

### Saving Sessions

Save your current tmux session layout:

```bash
pimpmytmux session save myproject
```

This saves:
- Window layout
- Pane configuration
- Working directories
- Running commands

### Restoring Sessions

```bash
# List saved sessions
pimpmytmux session list

# Restore a session
pimpmytmux session restore myproject
```

### Auto Save/Restore

Enable in configuration:

```yaml
modules:
  sessions:
    enabled: true
    auto_save: true      # Saves session when exiting tmux
    auto_restore: true   # Restores last session when starting
    save_interval: 15    # Auto-save every 15 minutes
```

---

## Session Templates

Session templates let you create multi-window sessions with predefined layouts and commands.

### Using Templates

```bash
# List available templates
pimpmytmux template list

# Create session from template
pimpmytmux template apply web-dev

# Save current session as template
pimpmytmux template save mytemplate

# Initialize example templates
pimpmytmux template init
```

### Template Format

Templates are YAML files in `~/.config/pimpmytmux/session-templates/`:

```yaml
name: web-dev
description: Web development session

# Variable substitution (prompted at apply time)
variables:
  PROJECT_NAME: "myproject"
  PROJECT_ROOT: "~/projects/${PROJECT_NAME}"

windows:
  - name: editor
    layout: main-vertical
    panes:
      - command: "${EDITOR:-vim} ."
        path: "${PROJECT_ROOT}"
      - command: "npm run dev"
        path: "${PROJECT_ROOT}"

  - name: terminal
    panes:
      - command: ""
        path: "${PROJECT_ROOT}"

  - name: logs
    panes:
      - command: "tail -f logs/app.log"
        path: "${PROJECT_ROOT}"
```

---

## Profiles

Profiles let you maintain multiple configurations for different contexts (work, personal, etc.).

### Managing Profiles

```bash
# List all profiles (current marked with *)
pimpmytmux profile list

# Switch to a profile
pimpmytmux profile switch work

# Create new profile
pimpmytmux profile create personal

# Create from existing profile
pimpmytmux profile create work-dark --from work

# Delete a profile
pimpmytmux profile delete old-profile
```

### Profile Storage

Profiles are stored in `~/.config/pimpmytmux/profiles/`:
```
profiles/
├── work/
│   └── pimpmytmux.yaml
├── personal/
│   └── pimpmytmux.yaml
└── current -> work/      # Symlink to active profile
```

---

## Project Detection

Automatically detect project type and apply appropriate settings.

### Using Detection

```bash
# Detect current directory
pimpmytmux detect

# Detect specific path
pimpmytmux detect ~/projects/myapp

# Auto-apply recommended layout
pimpmytmux detect --apply
```

### Supported Project Types

| Type | Detection Files | Recommended Layout |
|------|-----------------|-------------------|
| Node.js | `package.json` | dev-fullstack |
| Rust | `Cargo.toml` | dev-api |
| Go | `go.mod` | dev-api |
| Python | `setup.py`, `pyproject.toml` | dev-api |
| Ruby | `Gemfile` | dev-fullstack |
| Java | `pom.xml`, `build.gradle` | dev-api |
| PHP | `composer.json` | dev-fullstack |
| Elixir | `mix.exs` | dev-api |

---

## Git Sync

Synchronize your configuration across machines using a git repository.

### Setup

```bash
# Initialize sync with a git repository
pimpmytmux sync init git@github.com:user/pimpmytmux-config.git

# Check sync status
pimpmytmux sync status
```

### Daily Usage

```bash
# Push local changes
pimpmytmux sync push "Updated theme to dracula"

# Pull remote changes
pimpmytmux sync pull
```

### What Gets Synced

- `pimpmytmux.yaml` - Main configuration
- `themes/` - Custom themes
- `templates/` - Layout templates
- `session-templates/` - Session templates
- `profiles/` - All profiles

---

## Plugins

Extend pimpmytmux with community plugins.

### Managing Plugins

```bash
# List installed plugins
pimpmytmux plugin list

# Install from git URL
pimpmytmux plugin install https://github.com/user/pimpmytmux-weather

# Update all plugins
pimpmytmux plugin update

# Remove a plugin
pimpmytmux plugin remove weather

# Enable/disable without removing
pimpmytmux plugin disable weather
pimpmytmux plugin enable weather
```

### Plugin Hooks

Plugins can hook into pimpmytmux lifecycle:
- `on_install` - Run after installation
- `on_remove` - Run before removal
- `on_apply` - Run when config is applied
- `on_reload` - Run when config is reloaded

### Creating Plugins

See [plugins/README.md](plugins/README.md) for the plugin development guide.

---

## Backup and Migration

### Backups

pimpmytmux automatically backs up your configuration before changes.

```bash
# List available backups
pimpmytmux backup list

# Create manual backup
pimpmytmux backup create

# Restore a backup
pimpmytmux backup restore pimpmytmux.yaml.20260124-143022.bak

# Clean up old backups (keep 5 most recent)
pimpmytmux backup cleanup 5
```

### Migration

When upgrading pimpmytmux, migrate your configuration:

```bash
# Check if migration is needed
pimpmytmux migrate --status

# Run migration
pimpmytmux migrate
```

Migration automatically:
- Backs up your current config
- Updates deprecated settings
- Adds new default values
- Preserves your customizations

---

## Keybindings

### Default Keybindings

With default prefix `Ctrl+b`:

| Key | Action |
|-----|--------|
| `prefix + c` | New window |
| `prefix + n` | Next window |
| `prefix + p` | Previous window |
| `prefix + 1-9` | Go to window N |
| `prefix + \|` | Split horizontally |
| `prefix + -` | Split vertically |
| `prefix + z` | Zoom/unzoom pane |
| `prefix + x` | Close pane |
| `prefix + r` | Reload configuration |
| `prefix + [` | Enter copy mode |
| `prefix + ]` | Paste |

### Vim Mode

When `vim_mode: true`:

| Key | Action |
|-----|--------|
| `prefix + h` | Move to left pane |
| `prefix + j` | Move to down pane |
| `prefix + k` | Move to up pane |
| `prefix + l` | Move to right pane |
| `prefix + H` | Resize left |
| `prefix + J` | Resize down |
| `prefix + K` | Resize up |
| `prefix + L` | Resize right |

In copy mode:
| Key | Action |
|-----|--------|
| `v` | Begin selection |
| `y` | Copy selection |
| `/` | Search forward |
| `?` | Search backward |

### fzf Integration

When `fzf_integration: true`:

| Key | Action |
|-----|--------|
| `prefix + Ctrl+s` | Fuzzy session switcher |
| `prefix + Ctrl+w` | Fuzzy window switcher |

---

## Configuration Examples

### Minimal Setup

For users who want a clean, simple experience:

```yaml
theme: nord

general:
  prefix: C-b
  mouse: true
  base_index: 1
  history_limit: 10000

status_bar:
  position: bottom
  left: " #S "
  right: " %H:%M "

modules:
  sessions:
    enabled: false
  navigation:
    enabled: true
    vim_mode: false
    fzf_integration: false
  devtools:
    enabled: false
  monitoring:
    enabled: false

keybindings:
  preset: minimal
```

### Vim Power User

For Vim enthusiasts:

```yaml
theme: gruvbox

general:
  prefix: C-a         # Screen-like prefix
  mouse: false        # Keyboard only
  escape_time: 0      # Instant escape
  base_index: 1

modules:
  navigation:
    enabled: true
    vim_mode: true
    fzf_integration: true
    smart_splits: true

keybindings:
  preset: vim-heavy
  split_horizontal: "v"
  split_vertical: "s"
```

### DevOps/Monitoring Setup

For system administrators and DevOps:

```yaml
theme: matrix

general:
  prefix: C-a
  mouse: true

status_bar:
  position: top
  interval: 2
  right: "#{cpu} #{memory} | #{network} | %H:%M "

modules:
  monitoring:
    enabled: true
    components:
      - cpu
      - memory
      - battery
    network: true
```

### Writer/Distraction-Free

For focused writing:

```yaml
theme: catppuccin

general:
  prefix: C-b
  mouse: true

status_bar:
  position: bottom
  left: ""
  right: " %H:%M "
  left_length: 0
  right_length: 20

modules:
  sessions:
    enabled: true
  navigation:
    enabled: false
  devtools:
    enabled: false
  monitoring:
    enabled: false
```

---

## Workflows

### Development Workflow

**Starting a new project:**

```bash
# Start tmux
tmux

# Apply fullstack layout
pimpmytmux layout dev-fullstack

# Save this setup
pimpmytmux session save myproject
```

**Resuming work:**

```bash
# Restore your project
pimpmytmux session restore myproject
```

### DevOps Workflow

**Monitoring multiple servers:**

```bash
# Start with monitoring layout
tmux new -s monitoring
pimpmytmux layout monitoring

# In each pane, SSH to different servers
# Pane 1: ssh server1
# Pane 2: ssh server2
# etc.
```

### Writing Workflow

**Distraction-free writing (single pane):**

```bash
# Start with writing layout (closes other panes)
tmux new -s writing
pimpmytmux layout writing

# Open your editor
nvim mydocument.md
```

**Zen mode on existing layout:**

```bash
# Keep your current panes but hide distractions
pimpmytmux zen on

# When done, restore UI
pimpmytmux zen off
```

---

## Tips and Tricks

### Quick Theme Preview

Try themes quickly to find your favorite:

```bash
for theme in cyberpunk matrix dracula catppuccin nord gruvbox tokyo-night; do
  pimpmytmux theme $theme
  sleep 3
done
```

### Create Project-Specific Configs

Create different configs for different projects:

```bash
# Copy config for a project
cp ~/.config/pimpmytmux/pimpmytmux.yaml ~/.config/pimpmytmux/project-api.yaml

# Edit it
$EDITOR ~/.config/pimpmytmux/project-api.yaml

# Use it (create alias)
alias tmux-api='PIMPMYTMUX_CONFIG=~/.config/pimpmytmux/project-api.yaml tmux'
```

### Prefix Key Alternatives

If `Ctrl+b` is uncomfortable:
- `Ctrl+a` - Screen-like, common alternative
- `Ctrl+Space` - Easy to press, doesn't conflict with most apps

### Copy to System Clipboard

Ensure copy works with system clipboard:

```yaml
# macOS
platform:
  macos:
    copy_command: "pbcopy"

# Linux (X11)
platform:
  linux:
    copy_command: "xclip -selection clipboard"

# WSL
platform:
  wsl:
    copy_command: "clip.exe"
```

---

## FAQ

### How do I reload the config without restarting tmux?

Inside tmux, press `prefix + r` or run:
```bash
pimpmytmux reload
```

### Why are my colors wrong?

1. Ensure your terminal supports true color
2. Add `export TERM=xterm-256color` to your shell config
3. In your pimpmytmux config, ensure:
   ```yaml
   general:
     true_color: true
   ```

### How do I migrate from oh-my-tmux?

1. Backup your existing config:
   ```bash
   cp ~/.tmux.conf ~/.tmux.conf.backup
   ```
2. Install pimpmytmux
3. The installer will backup your existing config
4. Your old config is preserved in `~/.local/share/pimpmytmux/backups/`

### Can I use plugins with pimpmytmux?

Yes! Enable TPM (Tmux Plugin Manager):

```yaml
plugins:
  enabled: true
  list:
    - tmux-plugins/tmux-sensible
    - tmux-plugins/tmux-yank
    - christoomey/vim-tmux-navigator
```

### How do I change just the theme without editing the config?

```bash
pimpmytmux theme dracula
```

This updates the config and applies immediately.

### Why is fzf not working?

1. Ensure fzf is installed: `which fzf`
2. Enable fzf integration in config:
   ```yaml
   modules:
     navigation:
       fzf_integration: true
   ```
3. Reload: `pimpmytmux apply`

### How do I reset to defaults?

```bash
# Backup current config
cp ~/.config/pimpmytmux/pimpmytmux.yaml ~/.config/pimpmytmux/pimpmytmux.yaml.bak

# Reset to defaults
cp ~/.pimpmytmux/pimpmytmux.yaml.example ~/.config/pimpmytmux/pimpmytmux.yaml
pimpmytmux apply
```

---

## Further Reading

- [README.md](README.md) - Project overview and quick reference
- [INSTALL.md](INSTALL.md) - Detailed installation instructions
- [tmux Cheat Sheet](https://tmuxcheatsheet.com/) - General tmux reference
