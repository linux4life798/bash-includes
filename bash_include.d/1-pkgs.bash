#!/bin/bash
#
# This is a basic package manager for custom equivs packages.
# The idea is that you should always create topic/category
# equivs packages that depend on the packages you want to install.
#
# This tool supports packages residing on a remote filesystems that
# don't support fakeroot or root access. This creates an issue when
# we want to build or install packages. This tool subverts these
# limitations by always copying to tmp dir before performing these
# operations.
#
# Craig Hesling <craig@hesling.com>

_PKG_DIR="$(realpath "${HOME}/lib/packages")"
_PKG_NAME_MAX_WIDTH=30

# List packages that apply to the given hostname.
#
# Usage: pkg-list [-a | -i | -f | -h]
#
# Options:
#  -a or --all     - Show all packages available
#  -i or --ignores - Show ignored package set
#  -f or --forced  - Show forced packages for the current hostname
#  -h or --help    - Show a quick help message
pkg-list() {
  # Ignore list can be manually added to a specific group.
  local -a pkgs_all
  mapfile -t pkgs_all < <(pkg-list-all)

  local -a pkgs_ignores
  mapfile -t pkgs_ignores < <(pkg-ignores)

  local -a pkgs_forced
  mapfile -t pkgs_forced < <(pkg-list-forced-hostname "$(hostname -f)")

  for arg; do
    case "${arg}" in
      -h|--help)
        echo "Usage: pkg-list [-h | -a | -i | -f]"
        echo ""
        echo "--help, --all, --ignores, --forced"
        return 0
        ;;
      -a|--all)
        xargs -n1 <<<"${pkgs_all[*]}" | sort
        return 0
        ;;
      -i|--ignores)
        xargs -n1 <<<"${pkgs_ignores[*]}" | sort
        return 0
        ;;
      -f|--forced)
        xargs -n1 <<<"${pkgs_forced[*]}" | sort
        return 0
        ;;
    esac
  done

  local -A pkgs
  assoc-add-keys pkgs "${pkgs_all[@]}"
  assoc-rm-keys pkgs "${pkgs_ignores[@]}"
  assoc-add-keys pkgs "${pkgs_forced[@]}"

  xargs -n1 <<<"${pkgs[*]}" | sort
}

# Usage: pkg-find-control [pkg1 [pkg2 [...]]]
pkg-find-control() {
  local pkgs=( "$@" )

  for pkg in "${pkgs[@]}"; do
    find "$_PKG_DIR" -type f -name "${pkg}.equivs"
  done
}

# Usage: pkg-find-dir [pkg1 [pkg2 [...]]]
pkg-find-dir() {
  local pkgs=( "$@" )

  for pkg in "${pkgs[@]}"; do
    dirname "$(pkg-find-control "${pkg}")"
  done
}

# Usage: pkg-edit [pkg]
pkg-edit() {
  local pkg=$1

  if [ -z "${pkg}" ]; then
    select pkg in $(pkg-list); do
      if [ -n "${pkg}" ]; then
        break
      fi
    done
  fi

  ${EDITOR:-vim} "$(pkg-find-control "${pkg}")"
}

# Usage: pkg-show [pkg1 [pkg2 [...]]]
pkg-show() {
  local pkgs=( "$@" )

  for pkg in "${pkgs[@]}"; do
    cat "$(pkg-find-control "${pkg}")"
  done
}

# Usage: pkg-cd [pkg]
pkg-cd() {
  local pkg=$1

  if [ "${pkg}" = "" ]; then
    cd "$_PKG_DIR"
  else
    cd "$(pkg-find-dir "${pkg}")"
  fi
}

_pkg-find-deb() {
  local pkg=$1

  local pkg_dir="$(pkg-find-dir "${pkg}")"
  local ver="$(pkg-version-latest "${pkg}")"
  if ! ls -t "$pkg_dir"/${pkg}_${ver}_*.deb 2>/dev/null; then
    return 1
  fi
}

# Usage: pkg-version-installed [pkg1 [pkg2 [...]]]
pkg-version-installed() {
  local pkgs=( "$@" )
  local status=0

  if [ $# -eq 0 -o "$1" = "all" ]; then
    pkgs=( $(pkg-list) )
  fi

  local vers
  if ! vers="$(dpkg -l "${pkgs[@]}" 2>/dev/null)"; then
    status=1
  fi
  for pkg in "${pkgs[@]}"; do
    if [ -z "${pkg}" ]; then
      continue
    fi
    local ver=$(awk "/ii[[:space:]]+$pkg[[:space:]]+/{print \$3}" <<<"$vers")
    if [ -t 1 ]; then
      printf "%-*s" $_PKG_NAME_MAX_WIDTH "${pkg}"
    fi
    echo ${ver:--}
  done

  return $status
}

# Usage: pkg-version-latest [pkg1 [pkg2 [...]]]
pkg-version-latest() {
  local pkgs=( "$@" )

  if [ $# -eq 0 -o "$1" = "all" ]; then
    pkgs=( $(pkg-list) )
  fi

  if [ ${#pkgs[@]} -eq 1 ]; then
    local pkg=${pkgs[0]}
    grep '^Version: .*$' "$(pkg-find-control "${pkg}")" 2>/dev/null | cut -d ' ' -f 2
    if [ ${PIPESTATUS[0]} -ne 0 ]; then
      return 1
    fi
  else
    for pkg in "${pkgs[@]}"; do
      local ver=$(grep '^Version: .*$' "$(pkg-find-control "${pkg}")" 2>/dev/null | cut -d ' ' -f 2)
      if [ -t 1 ]; then
        printf "%-*s" $_PKG_NAME_MAX_WIDTH "${pkg}"
      fi
      echo ${ver:--}
    done
  fi
}

# Show the difference of package version and contents
# between the installed version and the remote latest description.
#
# Usage: pkg-diff [pkg1 [pkg2 [...]]]
pkg-diff() {
  local pkgs=( "$@" )

  if [ $# -eq 0 -o "$1" = "all" ]; then
    pkgs=( $(pkg-list) )
  fi

  for pkg in "${pkgs[@]}"; do
    local latest=$(pkg-version-latest "${pkg}")
    local installed=$(pkg-version-installed "${pkg}")
    printf "# \033[32m%-*s\033[m latest=%-5s | installed=%-5s\n" $_PKG_NAME_MAX_WIDTH "${pkg}:" "${latest}" "${installed}"

    local installed_deps="$(_pkg-field-installed Depends "${pkg}" | tr ' ' '\n' | sort)"
    local latest_deps="$(_pkg-field-latest Depends "${pkg}" | tr ' ' '\n' | sort)"
    if [[ "${installed_deps}" != "${latest_deps}" ]]; then
      printf "# Depends:\n"
      diff <(cat <<<"${installed_deps}") <(cat <<<"${latest_deps}")
    fi

    local installed_deps="$(_pkg-field-installed Recommends "${pkg}" | tr ' ' '\n' | sort)"
    local latest_deps="$(_pkg-field-latest Recommends "${pkg}" | tr ' ' '\n' | sort)"
    if [[ "${installed_deps}" != "${latest_deps}" ]]; then
      printf "# Recommends:\n"
      diff <(cat <<<"${installed_deps}") <(cat <<<"${latest_deps}")
    fi

    local installed_deps="$(_pkg-field-installed Suggests "${pkg}" | tr ' ' '\n' | sort)"
    local latest_deps="$(_pkg-field-latest Suggests "${pkg}" | tr ' ' '\n' | sort)"
    if [[ "${installed_deps}" != "${latest_deps}" ]]; then
      printf "# Suggests:\n"
      diff <(cat <<<"${installed_deps}") <(cat <<<"${latest_deps}")
    fi
  done
}

# Build and sign the .deb package.
# The package binary and signature are saved back to the remote package directory.
#
# Usage: pkg-build [pkg1 [pkg2 [...]]]
pkg-build() {
  local pkgs=( "$@" )

  if [ $# -eq 0 -o "$1" = "all" ]; then
    pkgs=( $(pkg-list) )
  fi

  local ret=0
  for pkg in "${pkgs[@]}"; do
    local tmp=`mktemp -d /tmp/pkg_build-${pkg}.XXXX`
    local pkg_control="$(pkg-find-control "${pkg}")"
    local pkg_dir="$(pkg-find-dir "${pkg}")"
    # Copy over all contents except compiled debs.
    # This is because it could contain extra files
    # to be compiled into the deb, like udev rules.
#    local srcs=( $(ls $pkg_dir | grep -v '.deb$') )
#    if ! cp -v -r "${srcs[@]/#/${pkg_dir}/}" "$tmp"; then
#      ret=1
#    fi
    echo "# pkg_control=${pkg_control}"
    echo "# pkg_dir=${pkg_dir}"
    echo "# tmp=${tmp}"

    # Copy over all pkg content except other .deb files
    echo "# Copying over pkg contents"
    # find "${pkg_dir}" -maxdepth 1 ! -path "${pkg_dir}" | grep -v ".deb$"
    # echo
    find "${pkg_dir}" -maxdepth 1 ! -path "${pkg_dir}" \
      | grep -v ".deb$" | xargs -d '\n' cp -r -t ${tmp}
    if [ $? -ne 0 ]; then
      ret=1
      break
    fi
    # if ! cp -v -r "${pkg_dir}"/* "$tmp"; then
    #   ret=1
    #   break
    # fi
    pushd "${tmp}"
    if ! equivs-build "$pkg_control"; then
      ret=1
      break
    fi
    local deb=$(echo *.deb)
    echo "Deb file is $deb"
    if ! cp "${deb}" "${pkg_dir}"; then
      ret=1
      break
    fi
    gpg --armor --output="${pkg_dir}/${deb}.asc" --detach-sign "${pkg_dir}/${deb}"
    popd
    rm -rf "${tmp}"
  done
  return $ret
}

# Usage: pkg-install [pkg1 [pkg2 [...]]]
pkg-install() {
  local pkgs=( "$@" )

  if [ $# -eq 0 -o "$1" = "all" ]; then
    pkgs=( $(pkg-list) )
  fi

  for pkg in "${pkgs[@]}"; do
    local pkg_dir="$(pkg-find-dir "${pkg}")"
    local pkg_file=$(ls -t "$pkg_dir"/*.deb | grep "${pkg}_$(pkg-version-latest "${pkg}")" | head -n1)
    echo "# Installing ${pkg_file}"

    local tmp=`mktemp -d /tmp/pkg_install.XXXX`
    local tmp_pkg="${tmp}/$(basename "${pkg_file}")"
    cp "${pkg_file}" "${tmp_pkg}"

    echo "# Verifying ${tmp_pkg}"
    if ! gpg --verify "${pkg_file}.asc" "${tmp_pkg}"; then
      echo "Error - Verification failed. Aborting."
      return 1
    fi

    echo "# Actually installing ${tmp_pkg}"
    sudo apt install -f "${tmp_pkg}"
    rm -rf "${tmp}"
  done
}

# Usage: pkg-upgrade [pkg1 [pkg2 [...]]]
pkg-upgrade() {
  local pkgs=( "$@" )

  if [ $# -eq 0 -o "$1" = "all" ]; then
    pkgs=( $(pkg-list) )
  fi

  for pkg in "${pkgs[@]}"; do
    local latest=$(pkg-version-latest "${pkg}")
    local installed=$(pkg-version-installed "${pkg}")

    if [ "$latest" != "$installed" ]; then
      pkg-diff "${pkg}"
      read -p"Continue [y/n]: " input
      if [ "$input" != "y" ]; then
        echo "# Skipping ${pkg}"
        echo
        continue
      fi

      if ! _pkg-find-deb "${pkg}" >/dev/null; then
        echo "# Building ${pkg}"
        if ! pkg-build "${pkg}"; then
          echo "# Error - Build failed"
          echo
          continue
        fi
      fi
      echo "# Installing $pkg"
      if ! pkg-install "${pkg}"; then
        echo "# Error - Install failed"
      fi
      echo
    else
      printf "# \033[32m%-*s\033[m latest=%-5s | installed=%-5s\n" $_PKG_NAME_MAX_WIDTH "${pkg}:" "${latest}" "${installed}"
    fi
  done

  return 0
}

# List packages that are marked as ignored, without applying host specific
# allows. These are listed sorted and one per line.
#
# Usage: pkg-ignore
pkg-ignores() {
  local file="${_PKG_DIR}/config/ignores"
  _pkg-file-tokens "${file}" | sort
}

# List all packages available, regardless of ignores and forced packages.
#
# Usage: pkg-list-all
pkg-list-all() {
  timeout 5 find "${_PKG_DIR}" -type f -name '*.equivs' | xargs -d'\n' -L1 basename -s '.equivs'
}

# List the packages forced for a given hostname.
#
# Usage: pkg-list-forced-hostname [hostname1 [hostname2...]]
pkg-list-forced-hostname() {
  for host; do
    [ -t 1 ] && echo "# Hostname '${host}'" >&2
    local hfile
    for hfile in "${_PKG_DIR}"/config/*.host; do
      local pat="$(basename "${hfile}" .host)"
      if [[ "${host}" =~ ${pat} ]]; then
        [ -t 1 ] && echo "# Applying '${hfile}'."  >&2
        _pkg-file-tokens "${hfile}"
      fi
    done
  done
}

#### Generic Deb Upgrader ####

# Usage: _pkg-field-latest <field> [pkg1 [pkg2 [...]]]
_pkg-field-latest() {
  local field="$1"
  shift

  local pkgs=( "$@" )

  if [ $# -eq 0 -o "$1" = "all" ]; then
    pkgs=( $(pkg-list) )
  fi

  for pkg in "${pkgs[@]}"; do
    local ver=$(_pkg-field-control "$(pkg-find-control "${pkg}")" "${field}" 2>/dev/null)
    if [ -t 1 ]; then
      printf "%-*s" $_PKG_NAME_MAX_WIDTH "${pkg}"
    fi
    echo ${ver:--}
  done
}

# Usage: _pkg-field-installed <field> [pkg1 [pkg2 [...]]]
_pkg-field-installed() {
  local field="$1"
  shift

  local pkgs=( "$@" )

  if [ $# -eq 0 -o "$1" = "all" ]; then
    pkgs=( $(pkg-list) )
  fi

  for pkg in "${pkgs[@]}"; do
    local ver=$(_pkg-field-apt-cache "${pkg}" "${field}" 2>/dev/null)
    if [ -t 1 ]; then
      printf "%-*s" $_PKG_NAME_MAX_WIDTH "${pkg}"
    fi
    echo ${ver:--}
  done
}

# Parse a particular field from a control file.
#
# Usage: _pkg-field-control <control_file> <field_name>
_pkg-field-control() {
  local file="$1"
  local field="$2"

  # We echo the perl output to trim extra whitespace and add a trailing newline.
  echo $(perl -ne 'next if /^#/; $p=(s/^'"${field}"':\s*/ / or (/^ / and $p)); s/,|\n|\([^)]+\)//mg; print if $p' <"${file}")
}

# Parse a particular field from installed package using apt-cache.
#
# Usage: _pkg-field-apt-cache <pkg> <field_name>
_pkg-field-apt-cache() {
  local pkg="$1"
  local field="$2"

  apt-cache show "${pkg}" 2>/dev/null | grep "^${field}:" | sed "s/^${field}: //" \
    | tr -d ' ' | tr ',' ' '
}

# Usage: assoc-add-keys-stdin <variable_name> < <(_pkg-file-tokens <file_path>)
#
# Combine all space/newline separated tokens seen in file_path
# onto one line each. Ignore comment lines that start with #.
_pkg-file-tokens() {
  local file="$1"

  if [[ ! -f "${file}" ]]; then
    echo "Error - file '${file}' doesn't exist." >&2
    return 1
  fi

  # Final step removes black lines.
  grep -v '^[[:space:]]*#' "${file}" | tr '[:space:]' '\n' | grep .
}

# Usage: _pkg-upgrade-deb <deb-path>
_pkg-upgrade-deb() {
	local deb=$1

	local pkgname
	if ! pkgname=$(dpkg-deb --field "$deb" Package); then
		return 1
	fi
	local verold vernew
	verold="$(dpkg -l "$pkgname" | tail -n1 | awk '{print $3}')"
	vernew="$(dpkg-deb --field "$deb" Version)"
	local default=$([[ "$verold" == "$vernew" ]] && echo no || echo yes)

	echo "# Package: $pkgname"
	echo
	echo "# Old version: $verold"
	echo "# New version: $vernew"
	read -p "Install? [$default] " input
	case $input in
		'')
			# Default
			[[ "$default" == "no" ]] && return 0
			;&
		y|Y|yes|YES)
			sudo dpkg -i "$deb"
			;;
		*)
			echo "# Aborting"
			;;
	esac
}


#### Completions ####

_pkg-complete-single() {
  COMPREPLY=()
  local word="${COMP_WORDS[COMP_CWORD]}"

  if [ "$COMP_CWORD" -eq 1 ]; then
    COMPREPLY=( $(compgen -W "$(pkg-list-all)" -- "$word") )
  fi
}

_pkg-complete-multi() {
  local word="${COMP_WORDS[COMP_CWORD]}"
  COMPREPLY=( $(compgen -W "$(pkg-list-all)" -- "$word") )
}

# Specify the multiple package names, including the special "all" keyword.
_pkg-complete-multi-all() {
  local word="${COMP_WORDS[COMP_CWORD]}"
  COMPREPLY=( $(compgen -W "all $(pkg-list-all)" -- "$word") )
}

complete -F _pkg-complete-single pkg-cd pkg-edit
complete -F _pkg-complete-multi pkg-find-dir pkg-find-control pkg-show
complete -F _pkg-complete-multi-all pkg-version-installed pkg-version-latest pkg-build pkg-install pkg-upgrade pkg-diff
