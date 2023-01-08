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

# The local directory where we save the remote bash include's offline cache.
_BINCLUDE_CACHE="$HOME/.bash_include_cache.d"
# The remote bash_aliases file that will auto update this file.
_BASH_ALIASES_REMOTE="$HOME/lib/bash-includes/bash_aliases"

# Usage: bash_aliases-update
#
# Update the local copy of ~/.bash_aliases from the remote copy.
bash_aliases-update() {
	if _binclude-timeout ls "${_BASH_ALIASES_REMOTE}" &>/dev/null; then
		touch "${HOME}/.bash_aliases"
		_binclude-timeout cp "${_BASH_ALIASES_REMOTE}" "${HOME}/.bash_aliases"
	fi
}

# Usage: _binclude-timeout <cmd> [args]
#
# Enforces a timeout for bash-include operations that may hang.
_binclude-timeout() {
	# This waits 3 seconds before sending SIGTERM.
	# It then waits the additional 1 second before sending SIGKILL.
	timeout --kill-after=1 3 "$@"
}

# Usage: binclude-dir <dir>
#
# Include all .bash files from a single directory level.
binclude-dir() {
	local dir=$1

	if [ -d "${dir}" ]; then
		for i in "${dir}"/*.bash; do
			. "$i"
		done
	fi
}

# Usage: cache_file=$(_binclude-cache-file-name <remote-dir>)
#
# Construct the cache file name for a given include directory.
_binclude-cache-file-name() {
	local remote_dir="$1"

	local cache_file="${remote_dir}"
	# Convert all whitespace to "--".
	cache_file="${cache_file//[[:space:]]/--}"
	# Convert all "/" path components to "++".
	cache_file="${cache_file//\//++}"
	echo "${_BINCLUDE_CACHE}/${cache_file}.bash"
}

# Usage: _binclude-cache-update <remote-dir>
#
# Cache the remote-dir include for later use.
_binclude-cache-update() {
	local remote_dir="$1"

	if [ ! -d "${remote_dir}" ]; then
		return 1
	fi
	if [ ! -d "${_BINCLUDE_CACHE}" ]; then
		mkdir -p "${_BINCLUDE_CACHE}"
	fi

	local cache_file=$(_binclude-cache-file-name "${remote_dir}")
	echo "# Generated on $(date)" >"${cache_file}"
	if [ -d "${remote_dir}" ]; then
		for i in "${remote_dir}"/*.bash; do
			echo >>"${cache_file}"
			echo "# From $i" >>"${cache_file}"
			grep -v "^[[:space:]]*#" "$i" >>"${cache_file}"
		done
	fi
}

# Usage: _binclude-cache-use <remote-dir>
#
# Source the cached version of the remote-dir include.
_binclude-cache-use() {
	local remote_dir="$1"

	local cache_file=$(_binclude-cache-file-name "${remote_dir}")
	if [ -f "${cache_file}" ]; then
		. "${cache_file}"
		return 0
	fi

	return 1
}

# Usage: binclude-remote <remote-dir>
#
# Include remote dir utilizing the cache mechanism.
binclude-remote() {
	local remote_dir="$1"

	# Running ls is forcing the remote filesystem to cache all
	# file listings, which will be globbed on later.
	if _binclude-timeout ls "${remote_dir}" &>/dev/null; then
		binclude-dir "${remote_dir}"
		( _binclude-cache-update "${remote_dir}" & )
		( bash_aliases-update & )
	else
		echo "Remote bash includes not available. Loading from cache." >&2
		_binclude-cache-use "${remote_dir}"
	fi
}

# Usage: binclude-clean
#
# Clear the cache for remote include.
binclude-clean() {
	gio trash "${_BINCLUDE_CACHE}"
}

#####################################################################

# Include remote bash_include.d
binclude-remote "${_BINCLUDE_REMOTE}"

# Include local bash_include.d
# Include last so that it can override remote.
binclude-dir "${_BINCLUDE_LOCAL}"
