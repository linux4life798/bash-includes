#!/bin/bash
#
# Hold host/platform specific include directives.
#
# Craig Hesling <craig@hesling.com>
# Jan 4, 2022

case "$(hostname -f)" in
    penguin)
        binclude-remote "${_BINCLUDE_REMOTE}/chromebook"
        ;;
esac