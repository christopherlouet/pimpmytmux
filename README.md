# pimpmytmux

A modern, modular tmux configuration framework. Easy to configure, productivity-focused, with beautiful geek-inspired themes.

```
╔═══════════════════════════════════════════════════════════════╗
║  ██████╗ ██╗███╗   ███╗██████╗ ███╗   ███╗██╗   ██╗████████╗ ║
║  ██╔══██╗██║████╗ ████║██╔══██╗████╗ ████║╚██╗ ██╔╝╚══██╔══╝ ║
║  ██████╔╝██║██╔████╔██║██████╔╝██╔████╔██║ ╚████╔╝    ██║    ║
║  ██╔═══╝ ██║██║╚██╔╝██║██╔═══╝ ██║╚██╔╝██║  ╚██╔╝     ██║    ║
║  ██║     ██║██║ ╚═╝ ██║██║     ██║ ╚═╝ ██║   ██║      ██║    ║
║  ╚═╝     ╚═╝╚═╝     ╚═╝╚═╝     ╚═╝     ╚═╝   ╚═╝      ╚═╝    ║
╚═══════════════════════════════════════════════════════════════╝
```

## Features

- **Easy YAML configuration** - No more cryptic tmux syntax
- **7 beautiful themes** - Cyberpunk, Matrix, Dracula, Catppuccin, Nord, Gruvbox, Tokyo Night
- **Interactive wizard** - Set up in seconds with guided configuration
- **Session management** - Save and restore your tmux sessions
- **Session templates** - Multi-window session creation with variable substitution
- **Profile system** - Multiple configurations for different contexts (work, personal, etc.)
- **Plugin system** - Extensible architecture with hooks and custom plugins
- **Git sync** - Synchronize your configuration across machines
- **Project detection** - Auto-detect project type and recommend layouts
- **Conditional keybindings** - Different bindings per hostname, project, or environment
- **Vim-style navigation** - hjkl pane navigation, vi copy mode
- **fzf integration** - Fuzzy search for sessions, windows, and panes
- **Dev layouts** - Pre-configured layouts for development workflows
- **Status bar widgets** - CPU, memory, battery, git status, and more
- **Cross-platform** - Works on Linux, macOS, and WSL

## Quick Start

### Installation

```bash
# Clone the repository
git clone https://github.com/christopherlouet/pimpmytmux.git ~/.config/pimpmytmux
cd ~/.config/pimpmytmux

# Run the installer
./install.sh

# Or run the interactive wizard
./bin/pimpmytmux wizard
```

> **Need help?** See the [Installation Guide](INSTALL.md) for platform-specific instructions (Ubuntu, Fedora, Arch, macOS, WSL2) and troubleshooting.

### Quick Setup

```bash
# Quick setup with a theme
pimpmytmux setup

# Or use specific theme directly
pimpmytmux init
pimpmytmux theme cyberpunk
pimpmytmux apply
```

## Commands

| Command | Description |
|---------|-------------|
| `pimpmytmux apply` | Generate and apply tmux configuration |
| `pimpmytmux reload` | Reload configuration (inside tmux) |
| `pimpmytmux theme <name>` | Switch to a different theme |
| `pimpmytmux themes` | List available themes |
| `pimpmytmux session save <name>` | Save current session |
| `pimpmytmux session restore <name>` | Restore a saved session |
| `pimpmytmux session list` | List saved sessions |
| `pimpmytmux template list` | List session templates |
| `pimpmytmux template apply <name>` | Create session from template |
| `pimpmytmux layout <name>` | Apply a predefined layout |
| `pimpmytmux layouts` | List available layouts |
| `pimpmytmux zen [on\|off]` | Toggle zen mode (hide status bar + borders) |
| `pimpmytmux profile list` | List available profiles |
| `pimpmytmux profile switch <name>` | Switch to a different profile |
| `pimpmytmux sync init <repo>` | Initialize git sync with repository |
| `pimpmytmux sync push` | Push config changes to remote |
| `pimpmytmux sync pull` | Pull config changes from remote |
| `pimpmytmux plugin list` | List installed plugins |
| `pimpmytmux plugin install <url>` | Install plugin from git URL |
| `pimpmytmux detect` | Detect project type and recommend layout |
| `pimpmytmux migrate` | Migrate config to latest version |
| `pimpmytmux backup list` | List available backups |
| `pimpmytmux backup restore <name>` | Restore a backup |
| `pimpmytmux wizard` | Run interactive setup wizard |
| `pimpmytmux setup` | Quick setup with defaults |
| `pimpmytmux edit` | Edit configuration file |
| `pimpmytmux check` | Validate configuration |
| `pimpmytmux status` | Show current status |

## Themes

### Cyberpunk (Default)
Neon pink and cyan, inspired by cyberpunk aesthetics.

### Matrix
Green on black, the classic terminal hacker look.

### Dracula
The popular dark theme with purple accents.

### Catppuccin
Soft pastel colors, easy on the eyes.

### Nord
Cool blue tones from the Arctic.

### Gruvbox
Retro warm colors with excellent contrast.

### Tokyo Night
Dark theme inspired by Tokyo city lights.

Switch themes with:
```bash
pimpmytmux theme dracula
```

## Configuration

Configuration is done through `~/.config/pimpmytmux/pimpmytmux.yaml`:

```yaml
# Theme
theme: cyberpunk

# General settings
general:
  prefix: C-b          # Prefix key (C-b, C-a, C-Space)
  mouse: true          # Enable mouse support
  base_index: 1        # Start numbering from 1
  history_limit: 50000 # Scrollback buffer size

# Status bar
status_bar:
  position: bottom     # top or bottom
  interval: 5          # Update interval in seconds

# Modules
modules:
  sessions:
    enabled: true
    auto_save: false   # Auto-save on exit
    auto_restore: false # Auto-restore on start

  navigation:
    enabled: true
    vim_mode: true     # hjkl navigation
    fzf_integration: true
    smart_splits: true

  devtools:
    enabled: true
    git_status: true
    project_detection: true

  monitoring:
    enabled: true
    cpu: true
    memory: true
    battery: true
```

See `pimpmytmux.yaml.example` for all available options, or check the [Usage Guide](USAGE.md) for detailed configuration examples and workflows.

## Layouts

Pre-configured window layouts for common workflows:

### dev-fullstack
Editor (60%) + Terminal + Server split. Perfect for full-stack development.

```
┌────────────────────┬───────────────────┐
│                    │    Terminal       │
│      Editor        ├───────────────────┤
│                    │    Server         │
└────────────────────┴───────────────────┘
```

### dev-api
Code (70%) + Logs (30%). Ideal for API development.

```
┌────────────────────────────┬───────────┐
│                            │           │
│          Code              │   Logs    │
│                            │           │
└────────────────────────────┴───────────┘
```

### monitoring
4-pane grid for system monitoring (htop, disk/memory, logs, network).

```
┌───────────────────┬───────────────────┐
│      htop         │   disk / memory   │
├───────────────────┼───────────────────┤
│      logs         │     network       │
└───────────────────┴───────────────────┘
```

### writing
Single maximized pane with zen mode enabled (hides status bar and borders).
**Note:** This layout will close other panes after confirmation.

Apply layouts with:
```bash
pimpmytmux layout dev-fullstack
pimpmytmux layout monitoring
```

## Zen Mode

Zen mode provides a distraction-free experience by hiding the status bar and pane borders.
Unlike layouts, zen mode only changes visual settings without affecting your panes.

```bash
pimpmytmux zen          # Toggle zen mode on/off
pimpmytmux zen on       # Enable zen mode
pimpmytmux zen off      # Disable zen mode
```

You can combine zen mode with any layout:
```bash
pimpmytmux layout monitoring   # Apply 4-pane monitoring layout
pimpmytmux zen                 # Hide status bar and borders
pimpmytmux zen                 # Toggle back to normal
```

## Keybindings

Default keybindings (with `C-b` prefix):

### Navigation
| Key | Action |
|-----|--------|
| `h/j/k/l` | Navigate panes (vim-style) |
| `H/J/K/L` | Resize panes |
| `\|` | Split horizontal |
| `-` | Split vertical |
| `z` | Zoom pane |
| `x` | Close pane |

### Windows
| Key | Action |
|-----|--------|
| `c` | New window |
| `n` | Next window |
| `p` | Previous window |
| `1-9` | Jump to window |

### Sessions (with fzf)
| Key | Action |
|-----|--------|
| `C-s` | fzf session switcher |
| `C-w` | fzf window switcher |

### Copy Mode
| Key | Action |
|-----|--------|
| `[` | Enter copy mode |
| `v` | Begin selection |
| `y` | Copy selection |
| `Escape` | Cancel |

## Dependencies

### Required
- tmux 3.0+

### Recommended
- [yq](https://github.com/mikefarah/yq) - YAML processor (Go version)
- [fzf](https://github.com/junegunn/fzf) - Fuzzy finder

### Optional
- [gum](https://github.com/charmbracelet/gum) - Fancy terminal prompts
- [jq](https://stedolan.github.io/jq/) - JSON processor
- Nerd Font - For icons in status bar

Install on Ubuntu/Debian:
```bash
sudo apt install tmux fzf
# For yq (Go version)
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq
```

Install on macOS:
```bash
brew install tmux fzf yq gum
```

## Directory Structure

```
~/.config/pimpmytmux/
├── pimpmytmux.yaml      # Your configuration
├── tmux.conf            # Generated tmux config
└── sessions/            # Saved sessions

~/.local/share/pimpmytmux/
├── cache/               # Cache for widgets
└── sessions/            # Session data
```

## Troubleshooting

### Configuration not applied
```bash
# Validate your config
pimpmytmux check

# Regenerate and apply
pimpmytmux apply
```

### Theme not working
Make sure you have true color support:
```bash
# Test true color support
printf '\e[48;2;255;0;0m  RED  \e[0m\n'
```

Set your terminal to support true color:
```bash
export TERM=xterm-256color
```

### fzf not working
Ensure fzf is installed and in your PATH:
```bash
which fzf
```

### Status bar widgets not updating
Check the cache directory:
```bash
ls -la ~/.cache/pimpmytmux/
```

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

### Adding a new theme

1. Create `themes/mytheme.yaml`
2. Define colors following the existing theme structure
3. Test with `pimpmytmux theme mytheme`

### Adding a new layout

1. Create `templates/mylayout.yaml`
2. Define layout structure
3. Optionally add a handler in `modules/sessions/layouts.sh`

## Documentation

| Guide | Description |
|-------|-------------|
| [Installation Guide](INSTALL.md) | Platform-specific installation (Ubuntu, Fedora, Arch, macOS, WSL2), dependencies, troubleshooting |
| [Usage Guide](USAGE.md) | Configuration examples, workflows, themes, layouts, keybindings, FAQ |

## License

GNU General Public License v3.0 - see LICENSE file for details.

## Acknowledgments

- Inspired by [oh-my-tmux](https://github.com/gpakosz/.tmux)
- Theme colors from popular terminal themes
- Icons from Nerd Fonts
