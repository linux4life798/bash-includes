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

# Enforces a timeout for bash-include operations that may hang.
#
# Usage: bi_timeout <cmd> [args]
bi_timeout() {
	timeout --kill-after=1 3 "$@"
}


_include_dir() {
	local dir=$1

	if [ -d "${dir}" ]; then
		for i in "${dir}"/*.bash; do
			. "$i"
		done
	fi
}

# Construct the cache file name for a given include directory.
# Usage: cache_file=$(_include_dir_cache_file_name <path_to_dir>)
_include_dir_cache_file_name() {
	local dir="$1"

	local cache_file="${dir}"
	# Convert all whitespace to "--".
	cache_file="${cache_file//[[:space:]]/--}"
	# Convert all "/" path components to "++".
	cache_file="${cache_file//\//++}"
	echo "${_BI_CACHE}/${cache_file}.bash"
}

_include_dir_cache_update() {
	local dir=$1
	local cache_file=$(_include_dir_cache_file_name "$dir")

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
	local cache_file=$(_include_dir_cache_file_name "$dir")

	if [ -f "${cache_file}" ]; then
		. "${cache_file}"
		return 0
	else
		return 1
	fi
}

# Update the local copy of ~/.bash_aliases from the remote copy.
_update_bash_aliases() {
	if bi_timeout ls "${_BI_ALIASES_REMOTE}" &>/dev/null; then
		bi_timeout cp "${_BI_ALIASES_REMOTE}" "${HOME}/.bash_aliases"
	fi
}

# Include local bash_include.d
_include_dir "$_BI_INCLUDE_LOCAL"
# Include remote bash_include.d
if bi_timeout ls "${_BI_INCLUDE_REMOTE}" &>/dev/null; then
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
unset bi_timeout