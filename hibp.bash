#!/usr/bin/env bash

# pass hibp - Password Store Extension (https://www.passwordstore.org/)
# Copyright (C) 2017 Moviuro <moviuro+git@gmail.com>.

cmd_hibp_usage() {
  cat <<-_EOF
Usage:
$PROGAME hibp [pass-name [...]]
  Queries the haveibeenpwned HTTPS API to check if the passwords have been
  compromised.
  See https://haveibeenpwned.com/API/v2#PwnedPasswords
_EOF
  exit 0
}

hibp_set_deps() {
  if command -v sha1sum >/dev/null 2>&1; then
    # GNU utils.
    # outputs a needless ` -` at the end, thus grep(1)
    hibp_sha() {
      printf '%s' "$1" | sha1sum | grep -Eo '[a-f0-9]{40}'
    }
  elif command -v sha1 >/dev/null 2>&1; then
    # BSD utils.
    hibp_sha() {
      printf '%s' "$1" | sha1
    }
  elif command -v openssl >/dev/null 2>&1; then
    hibp_sha() {
      printf '%s' "$1" | openssl sha1 | grep -Eo '[a-f0-9]{40}'
    }
  else
    echo "No SHA1 utilities found :(" >&2
    exit 1
  fi

  _endpoint=https://api.pwnedpasswords.com/pwnedpassword
  if command -v curl >/dev/null 2>&1; then
    hibp_query() {
      local _status _must_retry=0

      while [[ -n "$_must_retry" ]]; do
        _status="$(curl -s -I -X GET "$_endpoint/$(hibp_sha "$1")" | head -n 1)"
        case "$_status" in
          *200*) unset _must_retry; return 0 ;;
          *404*) unset _must_retry; return 1 ;;
          *429*) sleep 2;;
        esac
      done
    }
  elif command -v fetch >/dev/null 2>&1; then
    hibp_query() {
      fetch -vv -o /dev/null "$_endpoint/$(hibp_sha "$1")" 2>&1 | grep -q '200 OK'
    }
  else
    echo "No downloading utilities found :(" >&2
    exit 2
  fi
}

hibp_test() {
  local _path="$1"
  local _password="$(pass show "${_path%%.gpg}" 2>/dev/null | head -n 1)"

  if [[ -z "$_password" ]]; then
    return 0
  elif hibp_query "$_password"; then
    echo "$_path : compromised :("
  fi
}

cmd_hibp() {
  hibp_set_deps

  case "$1" in
    -h|--help) cmd_hibp_usage && exit 0 ;;
  esac

  local _path

  if [[ -n "$1" ]]; then
    for _path in "$@"; do
      hibp_test "$_path"
    done
  else
    cd "$PREFIX"
    for _path in **/*\.gpg; do
      hibp_test "$_path"
    done
  fi
}

cmd_hibp "$@"
