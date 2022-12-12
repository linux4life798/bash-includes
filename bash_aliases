#!/bin/bash
#
# This must be copied to ~/.bash_aliases.
# Its function is to source all of the local and remote bash include files,
# keep the local .bash_aliases file updated, and maintain an offline cache
# of the remote bash includes.
#
# Craig Hesling <craig@hesling.com>

# The local-only bash includes directory that will be sourced.
_BI_INCLUDE_LOCAL="$HOME/.bash_include.d"
# The remote bash includes directory that will be sourced.
# A cached version will be used if the remote path is unavailable.
_BI_INCLUDE_REMOTE="$HOME/lib/bash-includes/bash_include.d"
# The remote bash_aliases file that will auto update this file.
_BI_ALIASES_REMOTE="$HOME/lib/bash-includes/bash_aliases"
# The local directory where we save the remote bash include's offline cache.
_BI_CACHE="$HOME/.bash_include_cache.d"

# The timeout command with its arguments to use for potentially blocking
# commands.
_BI_TIMEOUT=( timeout --kill-after=1 3 )

_include_dir() {
	local dir=$1

	if [ -d "${dir}" ]; then
		for i in "${dir}"/*.bash; do
			. "$i"
		done
	fi
}

# Generate cache file name for a given directory
_include_dir_cache_file() {
	local dir=$1

	local cache_file=$dir
	cache_file="${cache_file// /__}"
	cache_file="${cache_file//\//___}.bash"
	echo "${_BI_CACHE}/${cache_file}"
}

_include_dir_cache_update() {
	local dir=$1
	local cache_file=$(_include_dir_cache_file "$dir")

	if [ ! -d "${dir}" ]; then
		return 1
	fi
	if [ ! -d "${_BI_CACHE}" ]; then
		mkdir -p "${_BI_CACHE}"
	fi

	echo "# Generated on $(date)" >"${cache_file}"
	if [ -d "${dir}" ]; then
		for i in "${dir}"/*.bash; do
			echo >>"${cache_file}"
			echo "# From $i" >>"${cache_file}"
			grep -v "^[[:space:]]*#" "$i" >>"${cache_file}"
		done
	fi
}

_include_dir_cache_use() {
	local dir=$1
	local cache_file=$(_include_dir_cache_file "$dir")

	if [ -f "${cache_file}" ]; then
		. "${cache_file}"
		return 0
	else
		return 1
	fi
}

# Update the local copy of ~/.bash_aliases from the remote copy.
_update_bash_aliases() {
	if "${_BI_TIMEOUT[@]}" ls "${_BI_ALIASES_REMOTE}" &>/dev/null; then
		"${_BI_TIMEOUT[@]}" cp "${_BI_ALIASES_REMOTE}" "${HOME}/.bash_aliases"
	fi
}

# Include local bash_include.d
_include_dir "$_BI_INCLUDE_LOCAL"
# Include DriveFS bash_include.d
if "${_BI_TIMEOUT[@]}" ls "${_BI_INCLUDE_REMOTE}" &>/dev/null; then
	_include_dir "${_BI_INCLUDE_REMOTE}"
	( _include_dir_cache_update "${_BI_INCLUDE_REMOTE}" & )
	( _update_bash_aliases & )
else
	echo "Remote bash includes not available. Loading from cache." >&2
	_include_dir_cache_use "${_BI_INCLUDE_REMOTE}"
fi

unset _update_bash_aliases
unset _include_dir_cache_use
unset _include_dir_cache_update
unset _include_dir_cache_file
unset _include_dir
unset _BI_TIMEOUT