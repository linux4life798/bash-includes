#!/bin/bash
# vim: set expandtab ts=4:
#
# This provides commands to help format messages.
#
# Craig Hesling <craig@hesling.com>

# If no messages argument given, read all from stdin.
# Usage: msg-font <font_code> <prefix> [messages...]
msg-font() {
    local font="$1"
    local prefix="$2"
    shift 2

    # Only emit font if stdout is a tty.
    # Note that stdout could be redirected to stderr,
    # which could also be a tty.
    if [ -t 1 ]; then
        printf "\E[${font}m"
    fi

    printf "${prefix}"

    if [ $# -eq 0 ]; then
        cat
    else
        echo "$@"
    fi

    # Only emit font if stdout is a tty.
    if [ -t 1 ]; then
        printf "\E[m"
    fi
}

# Print in Green+Bold.
# Usage: msg-info [messages...]
msg-info() {
    #printf "\E[32;01m# %s\E[m\n" "$*" >&2
    msg-font '32;01' "# " "$@" >&2
}

# Print in Red+Bold.
# Usage: msg-error [messages...]
msg-error() {
    #printf "\E[31;01m%s\E[m\n" "$*" >&2
    msg-font '31;01' "" "$@" >&2
}

# Usage:
#
# if msg-help "$@"; then
#     echo "The help message you would like to give."
#     return 0
# fi
#
msg-help() {
    for arg; do
        case "${arg}" in
            --)
                return 1
                ;;
            -h|--help)
                return 0
                ;;
        esac
    done

    return 1
}

# Print command in Blue and then run it.
# Usage: msg-run-confirm <msg|''> <default_answer|''> [cmd] [args...]
#
# Example: msg-run-confirm '' '' rm
msg-run-confirm() {
    local msg="$1"
    local default_answer="$2"
    shift 2

    local default=${default_answer:-y}
    read -p "${msg:-Run command}? [${default}] " input
    local parsed_input="${input:-${default}}"
    case "${parsed_input}" in
        y|Y|yes|Yes|YES)
            "$@"
            return $?
            ;;
        n|N|no|No|NO)
            echo "Not running."
            ;;
        *)
            echo "Didn't understand input '${parsed_input}'. Not running."
            return 1
            ;;
    esac
}

# Usage: confirm <msg|''> <default_answer|''> [cmd] [args...]
alias confirm=msg-run-confirm

# Print command in Blue and then run it.
# Usage: msg-run [cmd] [args...]
#
# Example: msg-run confirm
msg-run() {
    # Can't do $(realpath /dev/fd/1), since subshell
    # redirects command output via a pipe.
    local stdin="$(readlink /proc/$$/fd/0)"
    local stdout="$(readlink /proc/$$/fd/1)"
    local stderr="$(readlink /proc/$$/fd/2)"

    local redir=""
    if [[ ! ("${stdin}" =~ "/dev/pts/") ]]; then
        redir+=" <${stdin}"
    fi
    if [[ ! ("${stdout}" =~ "/dev/pts/") ]]; then
        redir+=" >${stdout}"
    fi
    if [[ ! ("${stderr}" =~ "/dev/pts/") ]]; then
        redir=" 2>${stderr}"
    fi

    #printf "\E[34m%s\E[m\n" "$*" >&2
    msg-font '34' '> ' "$*${redir}" >&2
    "$@"
}
