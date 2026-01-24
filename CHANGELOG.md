# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-01-24

### Added
- **Zen mode command**: `pimpmytmux zen [on|off]` to toggle distraction-free mode
  - Hides status bar and pane borders without affecting pane layout
  - Can be combined with any layout (e.g., `layout monitoring` + `zen on`)
  - Toggle functionality: running `zen` without arguments toggles the current state
- **Layout confirmation**: Destructive layouts now ask for confirmation before closing panes
  - The `writing` layout prompts before closing existing panes
  - Uses interactive confirmation via gum or standard prompt
- **Layout settings from YAML**: Layouts can now define settings in their YAML templates
  - `zen_mode: true` in template settings enables zen mode after applying layout
- **INSTALL.md**: Comprehensive installation guide with platform-specific instructions
  - Ubuntu/Debian installation steps
  - Fedora/RHEL/CentOS installation steps
  - Arch Linux installation steps
  - macOS (Homebrew) installation steps
  - WSL2 (Windows Subsystem for Linux) installation steps
  - Dependencies documentation (required, recommended, optional)
  - Troubleshooting section with common issues and solutions
- **USAGE.md**: Complete usage guide
  - Commands reference table
  - Configuration examples for different use cases (minimal, vim power user, devops, writer)
  - Themes documentation and customization guide
  - Layouts documentation with visual diagrams
  - Session management guide
  - Keybindings reference (default, vim mode, fzf)
  - Workflows for development, devops, and writing
  - Tips and tricks section
  - Comprehensive FAQ

### Changed
- **Monitoring layout**: Network pane now prefers `netstat -tulnp` over `ss` to show process names
- **Layout settings simplified**: Merged `status_bar` and `zen_mode` settings into single `zen_mode` option
- **README.md**: Updated with links to new documentation guides
  - Added reference to INSTALL.md in Quick Start section
  - Added reference to USAGE.md in Configuration section
  - Added new Documentation section with guides table
  - Fixed license reference (GPL v3.0)
- **INSTALL.md**: Updated to reflect current installer behavior
  - Fixed installation paths (`~/.pimpmytmux` instead of `~/.config/pimpmytmux`)
  - Updated `pimpmytmux status` expected output format
  - Added `pimpmytmux layouts` command
  - Added `pimpmytmux wizard` and `pimpmytmux setup` commands
  - Documented interactive dependency installation feature

## [0.1.0] - 2025-01-24

### Added
- Initial release of pimpmytmux
- YAML-based configuration system
- 7 built-in themes: Cyberpunk, Matrix, Dracula, Catppuccin, Nord, Gruvbox, Tokyo Night
- Interactive setup wizard with gum integration
- Session management (save/restore)
- Vim-style navigation module
- fzf integration for session/window/pane switching
- Developer tools module (git status, IDE layouts, project detection)
- System monitoring widgets (CPU, memory, battery, network, weather)
- Pre-configured development layouts (fullstack, API, monitoring, writing)
- Cross-platform support (Linux, macOS, WSL)
- Automated installer with dependency management
