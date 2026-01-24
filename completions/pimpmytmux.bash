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
    local commands="apply reload theme themes session layout layouts zen backup edit check status init wizard setup help version"

    # Session subcommands
    local session_cmds="save restore list"

    # Backup subcommands
    local backup_cmds="list restore create cleanup"

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
            esac
            ;;
    esac

    return 0
}

# Register the completion function
complete -F _pimpmytmux_completions pimpmytmux
