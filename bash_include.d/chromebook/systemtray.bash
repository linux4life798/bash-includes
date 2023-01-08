#!/bin/bash
#
# The dropbox app wants a systemtray icon for managing the service.
#
# Craig Hesling <craig@hesling.com>
# Jan 4, 2022

# Usage: systemtray-launch [start|stop]
systemtray-launch() {
	local action="${1:-start}"

	case "${action}" in
		-h|--help)
			echo "Configure and launch the app that acts as the systemtray for certain applications."
			echo
			echo "Usage: systemtray-launch [start|stop]"
			return 0
			;;
		start)
			;;
		stop)
			killall stalonetray
			return $?
			;;
		*)
			echo "Error - Invalid action '${action}'" >&2
			return 1
			;;
	esac

	if ! hash stalonetray 2>/dev/null; then
		echo "Error - Could not find stalonetray." >&2
		echo "You might need to install it 'apt install stalonetray.'" >&2
		return 1
	fi
	cat >~/.stalonetrayrc <<-EOF
		# Generated from systemtray-launch function on $(date).
		background "#777777"
		decorations all
		geometry 4x1+0+0
		icon_size 48
	EOF

	stalonetray &
	disown
}
