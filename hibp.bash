#!/usr/bin/env bash

# pass hibp - Password Store Extension (https://www.passwordstore.org/)
# Copyright (C) 2017 Moviuro <moviuro+git@gmail.com>.

cmd_hibp_usage() {
  cat <<-_EOF
Usage:
$PROGAME hibp [pass-name]
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

  _endpoint=https://haveibeenpwned.com/api/v2/pwnedpassword
  if command -v curl >/dev/null 2>&1; then
    hibp_query() {
      curl -fq "$_endpoint/$(hibp_sha "$1")" 2>&1 | grep -q '200'
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

cmd_hibp() {
  hibp_set_deps

  local _path
  local _password
  if [[ -n "$1" ]]; then
    for _path in "$@"; do
      _password="$(pass show "${_path%%.gpg}" 2>/dev/null | head -n 1)"
      if hibp_query "$_password"; then
        echo "$_path : compromised :("
      fi
    done
  else
    cd $PREFIX
    for _path in **/*\.gpg; do
      _password="$(pass show "${_path%%.gpg}" 2>/dev/null | head -n 1)"
      if hibp_query "$_password"; then
        echo "$_path : compromised :("
      fi
    done
  fi
}

cmd_hibp "$@"