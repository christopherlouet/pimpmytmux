#compdef pimpmytmux
# pimpmytmux - Zsh completion
# Source this file or add to your fpath:
#   fpath=(/path/to/pimpmytmux/completions $fpath)
#   autoload -Uz compinit && compinit

_pimpmytmux_themes() {
    local themes_dir="${PIMPMYTMUX_ROOT:-$HOME/.config/pimpmytmux}/themes"
    if [[ -d "$themes_dir" ]]; then
        local themes=(${themes_dir}/*.yaml(N:t:r))
        _describe -t themes 'theme' themes
    fi
}

_pimpmytmux_layouts() {
    local templates_dir="${PIMPMYTMUX_ROOT:-$HOME/.config/pimpmytmux}/templates"
    if [[ -d "$templates_dir" ]]; then
        local layouts=(${templates_dir}/*.yaml(N:t:r))
        _describe -t layouts 'layout' layouts
    fi
}

_pimpmytmux_sessions() {
    local sessions_dir="${PIMPMYTMUX_DATA_DIR:-$HOME/.local/share/pimpmytmux}/sessions"
    if [[ -d "$sessions_dir" ]]; then
        local sessions=(${sessions_dir}/*.json(N:t:r))
        _describe -t sessions 'session' sessions
    fi
}

_pimpmytmux_backups() {
    local backups_dir="${PIMPMYTMUX_DATA_DIR:-$HOME/.local/share/pimpmytmux}/backups"
    if [[ -d "$backups_dir" ]]; then
        local backups=(${backups_dir}/*.bak(N))
        _describe -t backups 'backup' backups
    fi
}

_pimpmytmux_profiles() {
    local profiles_dir="${PIMPMYTMUX_CONFIG_DIR:-$HOME/.config/pimpmytmux}/profiles"
    if [[ -d "$profiles_dir" ]]; then
        local profiles=()
        for dir in "$profiles_dir"/*/; do
            [[ -d "$dir" ]] && profiles+=("$(basename "$dir")")
        done
        # Filter out 'current' symlink
        profiles=("${(@)profiles:#current}")
        _describe -t profiles 'profile' profiles
    fi
}

_pimpmytmux() {
    local curcontext="$curcontext" state line
    typeset -A opt_args

    _arguments -C \
        '(-c --config)'{-c,--config}'[Use custom config file]:file:_files' \
        '(-v --verbose)'{-v,--verbose}'[Enable verbose output]' \
        '(-d --debug)'{-d,--debug}'[Enable debug output]' \
        '(-q --quiet)'{-q,--quiet}'[Suppress non-error output]' \
        '(-h --help)'{-h,--help}'[Show help]' \
        '--version[Show version]' \
        '--dry-run[Show what would be done]' \
        '--no-backup[Skip automatic backup]' \
        '--no-notifications[Disable tmux status bar notifications]' \
        '1: :->command' \
        '*: :->args'

    case $state in
        command)
            local commands=(
                'apply:Generate and apply tmux configuration'
                'reload:Reload tmux configuration'
                'theme:Switch to a different theme'
                'themes:List available themes'
                'profile:Profile management'
                'session:Session management'
                'layout:Apply a predefined layout'
                'layouts:List available layouts'
                'zen:Toggle zen mode'
                'backup:Backup management'
                'detect:Detect project type'
                'edit:Open configuration file in editor'
                'check:Validate configuration file'
                'status:Show current status'
                'init:Initialize pimpmytmux'
                'wizard:Interactive setup wizard'
                'setup:Quick setup with defaults'
                'help:Show help message'
                'version:Show version'
            )
            _describe -t commands 'command' commands
            ;;

        args)
            case $words[2] in
                theme)
                    if (( CURRENT == 3 )); then
                        _pimpmytmux_themes
                    elif (( CURRENT == 4 )); then
                        local opts=('--preview:Preview theme without applying')
                        _describe -t options 'option' opts
                    fi
                    ;;

                themes)
                    local opts=(
                        '--gallery:Show visual theme gallery'
                        '--interactive:Interactive theme selection'
                    )
                    _describe -t options 'option' opts
                    ;;

                profile)
                    if (( CURRENT == 3 )); then
                        local subcmds=(
                            'list:List available profiles'
                            'switch:Switch to a profile'
                            'create:Create a new profile'
                            'delete:Delete a profile'
                        )
                        _describe -t subcommands 'subcommand' subcmds
                    elif (( CURRENT == 4 )); then
                        case $words[3] in
                            switch|delete)
                                _pimpmytmux_profiles
                                ;;
                            create)
                                _message 'Profile name'
                                ;;
                        esac
                    elif (( CURRENT == 5 )); then
                        case $words[3] in
                            create)
                                local opts=('--from:Copy from existing profile')
                                _describe -t options 'option' opts
                                ;;
                        esac
                    elif (( CURRENT == 6 )); then
                        case $words[3] in
                            create)
                                if [[ "$words[5]" == "--from" ]]; then
                                    _pimpmytmux_profiles
                                fi
                                ;;
                        esac
                    fi
                    ;;

                session)
                    if (( CURRENT == 3 )); then
                        local subcmds=(
                            'save:Save current session'
                            'restore:Restore a saved session'
                            'list:List saved sessions'
                        )
                        _describe -t subcommands 'subcommand' subcmds
                    elif (( CURRENT == 4 )); then
                        case $words[3] in
                            save|restore)
                                _pimpmytmux_sessions
                                ;;
                        esac
                    fi
                    ;;

                layout)
                    if (( CURRENT == 3 )); then
                        _pimpmytmux_layouts
                    elif (( CURRENT == 4 )); then
                        local opts=('--preview:Preview layout without applying')
                        _describe -t options 'option' opts
                    fi
                    ;;

                zen)
                    if (( CURRENT == 3 )); then
                        local states=('on:Enable zen mode' 'off:Disable zen mode')
                        _describe -t states 'state' states
                    fi
                    ;;

                backup)
                    if (( CURRENT == 3 )); then
                        local subcmds=(
                            'list:List available backups'
                            'restore:Restore a backup'
                            'create:Create a manual backup'
                            'cleanup:Remove old backups'
                        )
                        _describe -t subcommands 'subcommand' subcmds
                    elif (( CURRENT == 4 )); then
                        case $words[3] in
                            restore)
                                _pimpmytmux_backups
                                ;;
                            cleanup)
                                _message 'Number of backups to keep'
                                ;;
                        esac
                    fi
                    ;;

                apply)
                    local opts=(
                        '--dry-run:Preview without applying'
                        '--no-backup:Skip automatic backup'
                    )
                    _describe -t options 'option' opts
                    ;;
            esac
            ;;
    esac
}

_pimpmytmux "$@"
