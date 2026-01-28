# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.2] - 2026-01-28

### Fixed
- **Clipboard integration**: The `platform.<os>.copy_command` configuration is now properly applied
  - Added `get_copy_command()` function to read platform-specific clipboard command
  - Modified `_generate_keybindings()` to use `copy-pipe-and-cancel` when `copy_command` is configured
  - Updated `generate_vim_copy_mode()` in vim-mode module to support system clipboard
  - Fixes copy/paste not working on Wayland (wl-copy) and other clipboard tools

### Added
- **New tests**: Added `tests/clipboard.bats` with 10 tests for clipboard functionality

## [1.0.1] - 2026-01-24

### Changed
- **Documentation**: Complete update for v1.0.0 features
  - README.md: Added all new commands (template, profile, sync, plugin, detect, migrate, backup)
  - INSTALL.md: Updated version number to v1.0.0
  - USAGE.md: Added comprehensive sections for all new features
    - Session Templates with YAML format examples
    - Profiles management guide
    - Project Detection with supported types
    - Git Sync workflow
    - Plugins usage and hooks
    - Backup and Migration guide
    - Conditional Keybindings with examples
  - Reorganized Commands Reference into logical groups

## [1.0.0] - 2026-01-24

### Added
- **Plugin system** (`lib/plugins.sh`): Extensible plugin architecture
  - `pimpmytmux plugin list`: List installed plugins
  - `pimpmytmux plugin install <url>`: Install plugin from git URL
  - `pimpmytmux plugin remove <name>`: Remove installed plugin
  - `pimpmytmux plugin update`: Update all plugins
  - `pimpmytmux plugin enable/disable`: Enable or disable plugins
  - Plugin hooks: `on_install`, `on_remove`, `on_apply`, `on_reload`
  - Plugin structure: `plugin.yaml` + optional scripts
  - Developer guide: `plugins/README.md`
- **CI/CD Pipelines** (`.github/workflows/`): Automated testing and releases
  - `test.yml`: BATS tests on push/PR, multi-platform (Ubuntu, macOS)
  - `release.yml`: Automatic releases on version tags
  - Shellcheck integration for code quality
  - Test coverage reporting
- **Configuration migration** (`lib/migrate.sh`): Automatic config upgrades
  - `pimpmytmux migrate`: Migrate config to latest version
  - `pimpmytmux migrate --status`: Show migration status
  - Automatic backup before migration
  - Rollback support
  - Version comparison utilities

## [0.5.0] - 2026-01-24

### Added
- **Configuration sync** (`lib/sync.sh`): Git-based configuration synchronization
  - `pimpmytmux sync init <repo>`: Initialize sync with a git repository
  - `pimpmytmux sync push [message]`: Push local changes to remote
  - `pimpmytmux sync pull`: Pull remote changes
  - `pimpmytmux sync status`: Show sync status
  - Syncs themes, templates, session-templates, and profiles
- **Conditional keybindings** (`lib/conditional.sh`): Context-aware keybindings
  - `hostname:<pattern>` condition: Different bindings per host
  - `project:<type>` condition: Different bindings per project type (node, rust, go, etc.)
  - `env:<VAR>=<value>` condition: Bindings based on environment variables
  - Define in `keybindings.conditional` section of config
- **Profile system** (`lib/profiles.sh`): Multiple configurations for different contexts
  - `pimpmytmux profile list`: Show all profiles with current marked
  - `pimpmytmux profile switch <name>`: Switch to different profile
  - `pimpmytmux profile create <name> [--from]`: Create new profile
  - `pimpmytmux profile delete <name>`: Delete profile (with confirmation)
  - Profiles stored in `~/.config/pimpmytmux/profiles/`
- **Project detection** (`lib/detect.sh`): Auto-detect project type and recommend layout
  - `pimpmytmux detect [path]`: Show project info
  - `pimpmytmux detect --apply`: Apply recommended layout
  - Supports: Node.js, Rust, Go, Python, Ruby, Java, PHP, Elixir
  - Auto-detects dev/test/build commands per project type
- **Session templates** (`modules/sessions/templates.sh`): Multi-window session creation
  - `pimpmytmux template list`: Show available templates
  - `pimpmytmux template apply <name>`: Create session from template
  - `pimpmytmux template save <name>`: Save current session as template
  - `pimpmytmux template init`: Create example templates
  - Variable substitution: `${PROJECT_NAME}`, `${PROJECT_ROOT}`, `${EDITOR}`

## [0.4.0] - 2026-01-24

### Added
- **Preview system** (`lib/preview.sh`): Theme and layout preview before applying
  - `pimpmytmux theme <name> --preview`: Preview theme colors and palette
  - `pimpmytmux layout <name> --preview`: Preview layout with ASCII diagram
  - True color ANSI support for accurate color display
- **Theme gallery** (`lib/gallery.sh`): Visual theme browser
  - `pimpmytmux themes --gallery`: Display all themes with color swatches
  - `pimpmytmux themes --interactive`: Interactive theme selection (requires gum)
  - Theme cards with background, accent colors and descriptions
- **Shell completions**: Full tab-completion support
  - Bash completion (`completions/pimpmytmux.bash`)
  - Zsh completion with descriptions (`completions/pimpmytmux.zsh`)
  - Dynamic completion for themes, layouts, sessions, backups
  - Automatic installation via `install.sh`
- **tmux notifications**: Status bar feedback after operations
  - Success/error/warning/info message styles
  - `--no-notifications` flag to disable
  - `PIMPMYTMUX_NOTIFICATIONS=false` environment variable

### Changed
- **Dry-run improved**: Colored diff output showing changes
  - Green for additions, red for removals, cyan for context
  - Line count summary
  - Fallback coloring when colordiff unavailable

## [0.3.0] - 2026-01-24

### Added
- **Config validation** (`lib/validation.sh`): Validate tmux config before applying
  - `validate_tmux_syntax()`: Check syntax via tmux source-file
  - `get_validation_errors()`: Parse and display tmux errors
  - `validate_before_apply()`: Integrated validation workflow
- **Backup system** (`lib/backup.sh`): Automatic backup before changes
  - `backup_config()`: Timestamped backup creation
  - `restore_backup()`: Restore from any backup
  - `list_backups()`: Show available backups
  - `cleanup_old_backups()`: Keep only N most recent
  - `pimpmytmux backup list/restore/create/cleanup` commands
- **Enhanced error messages**: Actionable error feedback
  - `error_with_suggestion()`: Error with recommended action
  - `log_error_detail()`: Structured error with context
  - `log_error_box()`: Boxed error for visibility
- **Module system**: Explicit module loading with debugging
  - `load_module()`: Controlled module loading with validation
  - `--debug` flag shows loaded modules
  - Tracking of loaded modules to prevent re-sourcing

### Changed
- **yq required**: Removed grep fallback for YAML parsing
  - Clear error message with installation instructions
  - `require_yq()` function for dependency check
- **Apply workflow**: Validate → Backup → Apply
  - Config validation before writing
  - Automatic backup (disable with `--no-backup`)
  - Rollback on validation failure

## [0.2.1] - 2026-01-24

### Changed
- **Monitoring layout**: Complete overhaul with modern tools and colorful output
  - `htop` as primary process monitor (fallback: top)
  - `duf` with colors for disk usage (fallback: df -h), filtered to show only local devices
  - Colorized `free -h` output (header=cyan, Mem=green, Swap=magenta)
  - Colorized network connections with `ss` (LISTEN=green, UNCONN=yellow, ESTAB=blue)
  - Log colorization with `ccze` if available (fallback: plain journalctl)
  - Flicker-free refresh using cursor positioning instead of screen clear

### Added
- **Installer**: Optional monitoring dependencies (htop, duf, ccze)
  - Interactive installation via `./install.sh deps`
  - `install_duf` function with binary download fallback
- **Documentation**: Monitoring layout dependencies in INSTALL.md and USAGE.md

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
