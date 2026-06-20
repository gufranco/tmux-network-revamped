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

# ping_ms_from_output TEXT -> integer milliseconds from a ping reply line.
ping_ms_from_output() {
  printf '%s\n' "${1}" | grep -m1 'time=' | sed -E 's/.*time=([0-9.]+).*/\1/' | cut -d. -f1
}

# count_established TEXT -> number of ESTABLISHED connections in netstat output.
count_established() {
  printf '%s\n' "${1}" | grep -c 'ESTABLISHED'
}

# valid_ipv4 TEXT -> the input when it is a dotted IPv4 address, else empty.
valid_ipv4() {
  local ip="${1%%[[:space:]]*}"
  [[ "${ip}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && echo "${ip}"
}

# vpn_from_links_linux TEXT -> first VPN interface from `ip -o link show up`.
vpn_from_links_linux() {
  printf '%s\n' "${1}" | grep -oE '(tun|tap|wg|ppp|nordlynx|tailscale)[0-9]*' | head -1
}

# vpn_from_routes_macos TEXT -> first VPN interface from `netstat -rn`.
vpn_from_routes_macos() {
  printf '%s\n' "${1}" | grep -oE '(utun|tun|tap|ipsec|ppp)[0-9]+' | head -1
}

# wifi_from_sp_macos TEXT -> RSSI in dBm from `system_profiler SPAirPortDataType`.
wifi_from_sp_macos() {
  printf '%s\n' "${1}" | grep -m1 'Signal / Noise' | grep -oE -- '-[0-9]+' | head -1
}

# wifi_from_proc_wireless TEXT -> RSSI in dBm from /proc/net/wireless.
wifi_from_proc_wireless() {
  printf '%s\n' "${1}" | awk 'NR>2 { gsub(/[^0-9-]/, "", $4); print $4; exit }'
}

# Host-probe seams.
_read_proc_net_dev() { cat /proc/net/dev 2>/dev/null; }
_read_ping_linux() { ping -c 1 -w 1 8.8.8.8 2>/dev/null; }
_read_ping_macos() { ping -c 1 -t 1 8.8.8.8 2>/dev/null; }
_read_netstat_an() { netstat -an 2>/dev/null; }
_read_public_ip() { curl -sf --connect-timeout 2 -m 3 https://icanhazip.com 2>/dev/null; }
_read_ip_links() { ip -o link show up 2>/dev/null; }
_read_route_table() { netstat -rn -f inet 2>/dev/null; }
_read_sp_airport() { system_profiler SPAirPortDataType 2>/dev/null; }
_read_proc_wireless() { cat /proc/net/wireless 2>/dev/null; }

# read_wifi -> wifi RSSI in dBm, empty when unavailable.
read_wifi() {
  if is_macos; then
    wifi_from_sp_macos "$(_read_sp_airport)"
  elif is_linux; then
    wifi_from_proc_wireless "$(_read_proc_wireless)"
  fi
}

# read_ping -> latency in milliseconds, empty when unavailable.
read_ping() {
  if is_linux; then
    ping_ms_from_output "$(_read_ping_linux)"
  elif is_macos; then
    ping_ms_from_output "$(_read_ping_macos)"
  fi
}

# read_connections -> count of established connections.
read_connections() {
  count_established "$(_read_netstat_an)"
}

# read_public_ip -> the public IPv4 address, empty when unavailable.
read_public_ip() {
  valid_ipv4 "$(_read_public_ip)"
}

# read_vpn -> the active VPN interface name, empty when none.
read_vpn() {
  if is_macos; then
    vpn_from_routes_macos "$(_read_route_table)"
  elif is_linux; then
    vpn_from_links_linux "$(_read_ip_links)"
  fi
}
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
export -f ping_ms_from_output
export -f count_established
export -f valid_ipv4
export -f vpn_from_links_linux
export -f vpn_from_routes_macos
export -f wifi_from_sp_macos
export -f wifi_from_proc_wireless
export -f _read_ping_linux
export -f _read_ping_macos
export -f _read_netstat_an
export -f _read_public_ip
export -f _read_ip_links
export -f _read_route_table
export -f _read_sp_airport
export -f _read_proc_wireless
export -f default_iface
export -f read_counters
export -f read_ping
export -f read_connections
export -f read_public_ip
export -f read_vpn
export -f read_wifi
