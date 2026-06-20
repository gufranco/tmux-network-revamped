#!/usr/bin/env bash
#
# network.sh: network throughput acquisition.
#
# Speed is the delta of interface byte counters between two refreshes. The pure
# functions parse counters and compute and format rates; the readers wrap host
# probes behind seams. The previous counters are held in tmux options by the
# dispatcher, so no temp file is needed to remember them.

[[ -n "${_NETWORK_REVAMPED_NETWORK_LOADED:-}" ]] && return 0
_NETWORK_REVAMPED_NETWORK_LOADED=1

_NET_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${_NET_LIB_DIR}/../utils/platform.sh"

# net_counters_from_proc TEXT IFACE -> "<rx> <tx>" from /proc/net/dev.
net_counters_from_proc() {
  local line
  line=$(printf '%s\n' "${1}" | grep -E "^[[:space:]]*${2}:")
  [[ -n "${line}" ]] || { echo ""; return 0; }
  line="${line#*:}"
  local -a f
  read -ra f <<< "${line}"
  local rx="${f[0]}" tx="${f[8]}"
  [[ "${rx}" =~ ^[0-9]+$ && "${tx}" =~ ^[0-9]+$ ]] || { echo ""; return 0; }
  echo "${rx} ${tx}"
}

# net_counters_from_netstat TEXT IFACE -> "<rx> <tx>" from `netstat -ib`.
net_counters_from_netstat() {
  printf '%s\n' "${1}" | awk -v i="${2}" '$1 == i && $7 ~ /^[0-9]+$/ { print $7" "$10; exit }'
}

# net_rate_compute CURRENT PREVIOUS SECONDS -> bytes per second, never negative.
net_rate_compute() {
  [[ "${1}" =~ ^[0-9]+$ && "${2}" =~ ^[0-9]+$ && "${3}" =~ ^[0-9]+$ ]] || { echo 0; return 0; }
  (( ${3} <= 0 )) && { echo 0; return 0; }
  local d=$(( ${1} - ${2} ))
  (( d < 0 )) && d=0
  echo $(( d / ${3} ))
}

# net_format_rate BYTES_PER_SEC -> human readable rate.
net_format_rate() {
  [[ "${1}" =~ ^[0-9]+$ ]] || { echo "0B/s"; return 0; }
  awk -v b="${1}" 'BEGIN {
    if (b >= 1048576) printf "%.1fMB/s", b / 1048576;
    else if (b >= 1024) printf "%.1fKB/s", b / 1024;
    else printf "%dB/s", b;
  }'
}

# Host-probe seams.
_read_proc_net_dev() { cat /proc/net/dev 2>/dev/null; }
_read_netstat() { netstat -ib 2>/dev/null; }
_default_iface_linux() { ip route show default 2>/dev/null | awk '/default/ { print $5; exit }'; }
_default_iface_macos() { route -n get default 2>/dev/null | awk '/interface:/ { print $2; exit }'; }

# default_iface -> the interface carrying the default route.
default_iface() {
  if is_linux; then
    _default_iface_linux
  elif is_macos; then
    _default_iface_macos
  fi
}

# read_counters IFACE -> "<rx> <tx>" for the interface, empty when unavailable.
read_counters() {
  local iface="${1}"
  [[ -n "${iface}" ]] || { echo ""; return 0; }
  if is_linux; then
    net_counters_from_proc "$(_read_proc_net_dev)" "${iface}"
  elif is_macos; then
    net_counters_from_netstat "$(_read_netstat)" "${iface}"
  else
    echo ""
  fi
}

export -f net_counters_from_proc
export -f net_counters_from_netstat
export -f net_rate_compute
export -f net_format_rate
export -f _read_proc_net_dev
export -f _read_netstat
export -f _default_iface_linux
export -f _default_iface_macos
export -f default_iface
export -f read_counters
