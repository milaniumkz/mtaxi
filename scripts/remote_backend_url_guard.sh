#!/usr/bin/env bash

mtaxi_validate_remote_backend_url() {
  local api_url="${1:-}"
  local error_prefix="${2:-MTaxi backend URL validation failed}"
  local host

  mtaxi_remote_backend_url_fail() {
    echo "$error_prefix: $*" >&2
    return 1
  }

  if [ -z "$api_url" ]; then
    mtaxi_remote_backend_url_fail "usage: MTAXI_BACKEND_URL=https://api.mtaxi.kz"
    return 1
  fi

  case "$api_url" in
    https://*) ;;
    *)
      mtaxi_remote_backend_url_fail "MTAXI_BACKEND_URL must be an external https:// backend URL"
      return 1
      ;;
  esac

  host="${api_url#https://}"
  host="${host%%/*}"
  if [[ "$host" == \[* ]]; then
    host="${host#\[}"
    host="${host%%\]*}"
  else
    host="${host%%:*}"
  fi
  host="$(printf '%s' "$host" | tr '[:upper:]' '[:lower:]')"

  mtaxi_host_second_octet_in_range() {
    local first="$1"
    local min="$2"
    local max="$3"
    local current_first current_second
    current_first="${host%%.*}"
    current_second="${host#*.}"
    current_second="${current_second%%.*}"
    [[ "$current_first" == "$first" ]] || return 1
    [[ "$current_second" =~ ^[0-9]+$ ]] || return 1
    [ "$current_second" -ge "$min" ] && [ "$current_second" -le "$max" ]
  }

  case "$host" in
    localhost|127.*|0.0.0.0|10.*|169.254.*|192.168.*|*.local|::1|fc*|fd*|fe8*|fe9*|fea*|feb*)
      mtaxi_remote_backend_url_fail "MTAXI_BACKEND_URL must not point to localhost, emulator or LAN"
      return 1
      ;;
  esac

  if mtaxi_host_second_octet_in_range 100 64 127 ||
    mtaxi_host_second_octet_in_range 172 16 31; then
    mtaxi_remote_backend_url_fail "MTAXI_BACKEND_URL must not point to a private LAN address"
    return 1
  fi

  printf '%s\n' "$api_url"
}
