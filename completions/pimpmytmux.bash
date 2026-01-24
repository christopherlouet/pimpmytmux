#!/usr/bin/env bash
# pimpmytmux - Bash completion
# Source this file or add to your .bashrc:
#   source /path/to/pimpmytmux/completions/pimpmytmux.bash
#
# Or copy to /etc/bash_completion.d/pimpmytmux

_pimpmytmux_completions() {
    local cur prev words cword
    _init_completion || return

    # Main commands
    local commands="apply reload theme themes profile session template layout layouts zen backup sync plugin detect migrate edit check status init wizard setup help version"

    # Profile subcommands
    local profile_cmds="list switch create delete"

    # Session subcommands
    local session_cmds="save restore list"

    # Template subcommands
    local template_cmds="list apply save init"

    # Backup subcommands
    local backup_cmds="list restore create cleanup"

    # Sync subcommands
    local sync_cmds="init push pull status"

    # Plugin subcommands
    local plugin_cmds="list install remove update enable disable"

    # Get available themes
    _pimpmytmux_themes() {
        local themes_dir="${PIMPMYTMUX_ROOT:-$HOME/.config/pimpmytmux}/themes"
        if [[ -d "$themes_dir" ]]; then
            find "$themes_dir" -maxdepth 1 -name "*.yaml" -exec basename {} .yaml \; 2>/dev/null
        fi
    }

    # Get available layouts
    _pimpmytmux_layouts() {
        local templates_dir="${PIMPMYTMUX_ROOT:-$HOME/.config/pimpmytmux}/templates"
        if [[ -d "$templates_dir" ]]; then
            find "$templates_dir" -maxdepth 1 -name "*.yaml" -exec basename {} .yaml \; 2>/dev/null
        fi
    }

    # Get saved sessions
    _pimpmytmux_sessions() {
        local sessions_dir="${PIMPMYTMUX_DATA_DIR:-$HOME/.local/share/pimpmytmux}/sessions"
        if [[ -d "$sessions_dir" ]]; then
            find "$sessions_dir" -maxdepth 1 -name "*.json" -exec basename {} .json \; 2>/dev/null
        fi
    }

    # Get backup files
    _pimpmytmux_backups() {
        local backups_dir="${PIMPMYTMUX_DATA_DIR:-$HOME/.local/share/pimpmytmux}/backups"
        if [[ -d "$backups_dir" ]]; then
            find "$backups_dir" -maxdepth 1 -name "*.bak" 2>/dev/null
        fi
    }

    # Get available profiles
    _pimpmytmux_profiles() {
        local profiles_dir="${PIMPMYTMUX_CONFIG_DIR:-$HOME/.config/pimpmytmux}/profiles"
        if [[ -d "$profiles_dir" ]]; then
            for dir in "$profiles_dir"/*/; do
                [[ -d "$dir" ]] && basename "$dir"
            done | grep -v '^current$' 2>/dev/null
        fi
    }

    case "${cword}" in
        1)
            # Complete main commands
            COMPREPLY=($(compgen -W "$commands" -- "$cur"))
            ;;
        2)
            case "${prev}" in
                theme)
                    # Complete theme names
                    COMPREPLY=($(compgen -W "$(_pimpmytmux_themes)" -- "$cur"))
                    ;;
                themes)
                    # Complete themes options
                    COMPREPLY=($(compgen -W "--gallery --interactive" -- "$cur"))
                    ;;
                session)
                    # Complete session subcommands
                    COMPREPLY=($(compgen -W "$session_cmds" -- "$cur"))
                    ;;
                layout)
                    # Complete layout names
                    COMPREPLY=($(compgen -W "$(_pimpmytmux_layouts)" -- "$cur"))
                    ;;
                zen)
                    # Complete zen options
                    COMPREPLY=($(compgen -W "on off" -- "$cur"))
                    ;;
                backup)
                    # Complete backup subcommands
                    COMPREPLY=($(compgen -W "$backup_cmds" -- "$cur"))
                    ;;
                sync)
                    # Complete sync subcommands
                    COMPREPLY=($(compgen -W "$sync_cmds" -- "$cur"))
                    ;;
                plugin)
                    # Complete plugin subcommands
                    COMPREPLY=($(compgen -W "$plugin_cmds" -- "$cur"))
                    ;;
                profile)
                    # Complete profile subcommands
                    COMPREPLY=($(compgen -W "$profile_cmds" -- "$cur"))
                    ;;
                template)
                    # Complete template subcommands
                    COMPREPLY=($(compgen -W "$template_cmds" -- "$cur"))
                    ;;
                apply)
                    # Complete apply options
                    COMPREPLY=($(compgen -W "--dry-run --no-backup --no-notifications" -- "$cur"))
                    ;;
                *)
                    ;;
            esac
            ;;
        3)
            local cmd="${words[1]}"
            local subcmd="${words[2]}"

            case "$cmd" in
                theme)
                    # Complete theme options
                    COMPREPLY=($(compgen -W "--preview" -- "$cur"))
                    ;;
                layout)
                    # Complete layout options
                    COMPREPLY=($(compgen -W "--preview" -- "$cur"))
                    ;;
                session)
                    case "$subcmd" in
                        save|restore)
                            # Complete session names
                            COMPREPLY=($(compgen -W "$(_pimpmytmux_sessions)" -- "$cur"))
                            ;;
                    esac
                    ;;
                backup)
                    case "$subcmd" in
                        restore)
                            # Complete backup files
                            COMPREPLY=($(compgen -W "$(_pimpmytmux_backups)" -- "$cur"))
                            ;;
                        cleanup)
                            # Suggest common cleanup numbers
                            COMPREPLY=($(compgen -W "3 5 10" -- "$cur"))
                            ;;
                    esac
                    ;;
                profile)
                    case "$subcmd" in
                        switch|delete)
                            # Complete profile names
                            COMPREPLY=($(compgen -W "$(_pimpmytmux_profiles)" -- "$cur"))
                            ;;
                        create)
                            # Just suggest a name placeholder
                            COMPREPLY=()
                            ;;
                    esac
                    ;;
            esac
            ;;
    esac

    return 0
}

# Register the completion function
complete -F _pimpmytmux_completions pimpmytmux
