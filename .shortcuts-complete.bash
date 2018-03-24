# bash completion for shortcuts https://github.com/rodionovd/shortcuts
function _shortcuts()
{
    local word=${COMP_WORDS[COMP_CWORD]}
    case $COMP_CWORD in 
    "1" )
        COMPREPLY=($(compgen -W "read import create update delete" -- "${word}"))
        ;;
    "2" )
        case ${COMP_WORDS[1]} in
            "read" )
                COMPREPLY=($(compgen -f -W "--as-plist" -- "${word}"))
                ;;
            "import" )
                COMPREPLY=($(compgen -f -W "--force" -- "${word}"))
                ;;
            "create" )
                COMPREPLY=($(compgen -W "--force" -- "${word}"))
                ;;
            "delete" )
                # the grep is necessary, because of multiline phrases, which may be problematic
                KEYS=$(shortcuts read | grep -e '[[:digit:]+]: \".*\"' | cut -d ' ' -f 2 | sort)
                COMPREPLY=($(compgen -W "$KEYS" -- "${word}"))
                ;;
        esac
        ;;
    "3" )
        case ${COMP_WORDS[1]} in
            "read" )
                case ${COMP_WORDS[2]} in
                    "--as-plist" )
                        COMPREPLY=($(compgen -f -- "${word}"))
                        ;;
                esac
                ;;
            "import" )
                case ${COMP_WORDS[2]} in
                    "--force" )
                        COMPREPLY=($(compgen -f -- "${word}"))
                        ;;
                esac
                ;;
        esac
        ;;
    esac
}
complete -F _shortcuts shortcuts
