#!/bin/bash
#
# This must be copied to ~/.bash_aliases.
# Its function is to source all of the local and remote bash include files,
# keep the local .bash_aliases file updated, and maintain an offline cache
# of the remote bash includes.
#
# Craig Hesling <craig@hesling.com>

# The local-only bash includes directory that will be sourced.
_BINCLUDE_LOCAL="$HOME/.bash_include.d"
# The remote bash includes directory that will be sourced.
# A cached version will be used if the remote path is unavailable.
_BINCLUDE_REMOTE="$HOME/lib/bash-includes/bash_include.d"
# The remote bash_aliases file that will auto update this file.
_BASH_ALIASES_REMOTE="$HOME/lib/bash-includes/bash_aliases"
# The local directory where we save the remote bash include's offline cache.
_BINCLUDE_CACHE="$HOME/.bash_include_cache.d"

# Enforces a timeout for bash-include operations that may hang.
#
# Usage: bi_timeout <cmd> [args]
binclude-timeout() {
	timeout --kill-after=1 3 "$@"
}


binclude-dir() {
	local dir=$1

	if [ -d "${dir}" ]; then
		for i in "${dir}"/*.bash; do
			. "$i"
		done
	fi
}

# Construct the cache file name for a given include directory.
# Usage: cache_file=$(_include_dir_cache_file_name <path_to_dir>)
binclude-cache-file-name() {
	local dir="$1"

	local cache_file="${dir}"
	# Convert all whitespace to "--".
	cache_file="${cache_file//[[:space:]]/--}"
	# Convert all "/" path components to "++".
	cache_file="${cache_file//\//++}"
	echo "${_BINCLUDE_CACHE}/${cache_file}.bash"
}

binclude-cache-update() {
	local dir=$1
	local cache_file=$(binclude-cache-file-name "$dir")

	if [ ! -d "${dir}" ]; then
		return 1
	fi
	if [ ! -d "${_BINCLUDE_CACHE}" ]; then
		mkdir -p "${_BINCLUDE_CACHE}"
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

binclude-cache-use() {
	local dir=$1
	local cache_file=$(binclude-cache-file-name "$dir")

	if [ -f "${cache_file}" ]; then
		. "${cache_file}"
		return 0
	else
		return 1
	fi
}

# Update the local copy of ~/.bash_aliases from the remote copy.
bash_aliases-update() {
	if binclude-timeout ls "${_BASH_ALIASES_REMOTE}" &>/dev/null; then
		binclude-timeout cp "${_BASH_ALIASES_REMOTE}" "${HOME}/.bash_aliases"
	fi
}

# Include local bash_include.d
binclude-dir "$_BINCLUDE_LOCAL"
# Include remote bash_include.d
if binclude-timeout ls "${_BINCLUDE_REMOTE}" &>/dev/null; then
	binclude-dir "${_BINCLUDE_REMOTE}"
	( binclude-cache-update "${_BINCLUDE_REMOTE}" & )
	( bash_aliases-update & )
else
	echo "Remote bash includes not available. Loading from cache." >&2
	binclude-cache-use "${_BINCLUDE_REMOTE}"
fi

unset bash_aliases-update
unset binclude-cache-use
unset binclude-cache-update
unset binclude-cache-file-name
unset binclude-dir
unset binclude-timeout