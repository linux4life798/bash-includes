#!/bin/bash
# vim: set expandtab ts=4:
#
# Functions for working with associative arrays.
# Currently, these are used to implement sets for quick lookup.
#
# assoc-add-key
# assoc-rm-keys
# assoc-add-keyvals-stdin
#
# Craig Hesling <craig@hesling.com>

# Usage: assoc-add-keys <associate_array_name> [item1 [item2...]]
assoc-add-keys() {
  local -n _arr="${1}"
  shift

  for key; do
    _arr["${key}"]="${key}"
  done
}

# Usage: assoc-rm-keys <associate_array_name> [item1 [item2...]
assoc-rm-keys() {
  local -n _arr="${1}"
  shift

  for key; do
    unset _arr["${key}"]
  done
}

# Usage: assoc-and-keys <associate_array_name> [item1 [item2...]
assoc-rm-keys() {
  local -n _arr="${1}"
  shift

  for key; do
    unset _arr["${key}"]
  done
}

# Read one line of space separated tokens as keys.
#
# NOTE: We return the read return status. This will be 1 if EOF was seen.
#       So, if you strip all newlines (tr -d '\n'), this will return 1.
#
# Usage: assoc-add-keys-stdin <associate_array_name> < <(echo key1 key2)
assoc-add-keys-stdin() {
  local -n _arr1="${1}"
  shift

  local -a keys
  read -r -a keys
  local ret=$?
  assoc-add-keys _arr1 "${keys[@]}"
  return $ret
}

# Read key value pairs from stdin, until EOF.
# We expect on key=value per line.
# There may be space surrounding the key, =, and value.
#
# Usage: assoc-add-keyvals-stdin <associate_array_name> < <(echo K1=v1; echo K2 = v2;)
assoc-add-keyvals-stdin() {
  local -n _arr="${1}"
  shift

  while read -r key equals value; do
    if [[ -n "${key}" && "${equals}" == "=" && -n "${value}" ]]; then
      # echo "'[${key}]=${value}'"
      _arr["${key}"]="${value}"
    fi
  done < <(sed 's/=/ = /')
}
