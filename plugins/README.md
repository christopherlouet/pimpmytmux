# pimpmytmux Plugin Development Guide

This guide explains how to create plugins for pimpmytmux.

## Plugin Structure

A pimpmytmux plugin is a directory with the following structure:

```
my-plugin/
├── plugin.yaml      # Required: Plugin metadata
├── tmux.conf        # Optional: tmux configuration to inject
├── config.sh        # Optional: Bash config loaded at startup
├── on_install.sh    # Optional: Runs after plugin installation
├── on_remove.sh     # Optional: Runs before plugin removal
├── on_apply.sh      # Optional: Runs when config is applied
└── on_reload.sh     # Optional: Runs when config is reloaded
```

## plugin.yaml

The `plugin.yaml` file is required and must contain at least:

```yaml
name: my-plugin
version: "1.0.0"
description: My awesome plugin
author: Your Name
```

### Optional Fields

```yaml
name: my-plugin
version: "1.0.0"
description: My awesome plugin
author: Your Name
homepage: https://github.com/user/pimpmytmux-plugin
license: MIT
dependencies:
  - fzf
  - jq
min_pimpmytmux_version: "1.0.0"
```

## Hook Scripts

All hook scripts receive environment variables:

| Variable | Description |
|----------|-------------|
| `PIMPMYTMUX_PLUGIN_DIR` | Path to the plugin directory |
| `PIMPMYTMUX_PLUGIN_NAME` | Plugin name |
| `PIMPMYTMUX_ROOT` | pimpmytmux installation directory |
| `PIMPMYTMUX_CONFIG_DIR` | User config directory |

### on_install.sh

Runs once after installation. Use for:
- Downloading additional resources
- Compiling native extensions
- Creating initial config files

```bash
#!/usr/bin/env bash
echo "Installing my-plugin..."
# Download resources, compile, etc.
```

### on_remove.sh

Runs before removal. Use for:
- Cleanup of generated files
- Removing cached data

```bash
#!/usr/bin/env bash
echo "Cleaning up..."
rm -rf "$HOME/.cache/my-plugin"
```

### on_apply.sh

Runs when `pimpmytmux apply` is executed. Use for:
- Generating dynamic configuration
- Updating runtime state

### on_reload.sh

Runs when `pimpmytmux reload` is executed. Use for:
- Quick updates that don't need full regeneration

## tmux.conf

The `tmux.conf` file contains tmux commands that will be appended to the generated configuration:

```tmux
# my-plugin tmux configuration
bind M-f run-shell "my-plugin-fzf"
set -g @my-plugin-option "value"
```

## config.sh

The `config.sh` file is sourced when pimpmytmux loads. Use for:
- Defining helper functions
- Setting environment variables
- Registering callbacks

```bash
#!/usr/bin/env bash
# my-plugin configuration

MY_PLUGIN_DATA_DIR="${PIMPMYTMUX_DATA_DIR}/my-plugin"

my_plugin_status() {
    echo "my-plugin is loaded"
}
```

## Example Plugin

Here's a complete example of a simple plugin:

### plugin.yaml

```yaml
name: git-status
version: "1.0.0"
description: Show git status in tmux status bar
author: pimpmytmux
dependencies:
  - git
```

### tmux.conf

```tmux
# Git status in status bar
set -g status-right "#(cd #{pane_current_path} && git branch --show-current 2>/dev/null) | %H:%M"
```

### on_install.sh

```bash
#!/usr/bin/env bash
echo "git-status plugin installed!"
echo "The status bar will now show the current git branch."
```

## Installing Your Plugin

### From Local Directory

```bash
# During development
cp -r my-plugin ~/.local/share/pimpmytmux/plugins/
pimpmytmux plugin enable my-plugin
pimpmytmux apply
```

### From Git Repository

```bash
pimpmytmux plugin install https://github.com/user/pimpmytmux-git-status
```

## Publishing Your Plugin

1. Create a public git repository
2. Ensure `plugin.yaml` is in the root
3. Add a README with installation instructions
4. Share the repository URL

Recommended naming convention: `pimpmytmux-<plugin-name>`

## API Reference

Plugins can use these functions from pimpmytmux:

| Function | Description |
|----------|-------------|
| `log_info <msg>` | Print info message |
| `log_success <msg>` | Print success message |
| `log_warn <msg>` | Print warning message |
| `log_error <msg>` | Print error message |
| `check_command <cmd>` | Check if command exists |
| `get_config <path> [default]` | Read from config file |
| `is_inside_tmux` | Check if inside tmux |
| `get_platform` | Get current platform |

## Best Practices

1. **Minimal Dependencies**: Only require what's necessary
2. **Graceful Degradation**: Handle missing dependencies gracefully
3. **No Global Pollution**: Use unique prefixes for functions/variables
4. **Proper Cleanup**: Implement `on_remove.sh` if you create files
5. **Documentation**: Include a README in your plugin
6. **Versioning**: Use semantic versioning
7. **Testing**: Test on multiple platforms if possible

## Troubleshooting

### Plugin not loading

1. Check `plugin.yaml` syntax with `yq`
2. Verify the `name` field matches directory name
3. Ensure scripts are executable: `chmod +x on_*.sh`

### Hook not running

1. Make the script executable
2. Check for shebang: `#!/usr/bin/env bash`
3. Look for syntax errors: `bash -n on_install.sh`

### Configuration not applied

1. Ensure plugin is enabled: `pimpmytmux plugin list`
2. Run `pimpmytmux apply` after changes
3. Check `tmux.conf` syntax
