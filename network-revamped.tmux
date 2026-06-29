#!/usr/bin/env bash
#
# network-revamped.tmux: TPM entry point.
#
# Replaces the #{net_*} placeholders in status-left and status-right with calls
# to the dispatcher, which reads cached values and never blocks the render.

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NET_CMD="${PLUGIN_DIR}/src/network.sh"

placeholders=(
  "\#{net_download}"
  "\#{net_upload}"
  "\#{net_speed}"
  "\#{net_fg_color}"
  "\#{net_bg_color}"
  "\#{net_vpn_name}"
  "\#{net_vpn}"
  "\#{net_ip}"
  "\#{net_connections}"
  "\#{net_ping}"
  "\#{net_public_ip}"
  "\#{net_wifi}"
  "\#{net_ssid}"
  "\#{net_online}"
)

commands=(
  "#(${NET_CMD} download)"
  "#(${NET_CMD} upload)"
  "#(${NET_CMD} speed)"
  "#(${NET_CMD} fg_color)"
  "#(${NET_CMD} bg_color)"
  "#(${NET_CMD} vpn_name)"
  "#(${NET_CMD} vpn)"
  "#(${NET_CMD} ip)"
  "#(${NET_CMD} connections)"
  "#(${NET_CMD} ping)"
  "#(${NET_CMD} public_ip)"
  "#(${NET_CMD} wifi)"
  "#(${NET_CMD} ssid)"
  "#(${NET_CMD} online)"
)

interpolate() {
  local value="${1}"
  local i
  for (( i = 0; i < ${#placeholders[@]}; i++ )); do
    value="${value//${placeholders[i]}/${commands[i]}}"
  done
  echo "${value}"
}

update_option() {
  local option="${1}"
  local current
  current=$(tmux show-option -gqv "${option}")
  tmux set-option -gq "${option}" "$(interpolate "${current}")"
}

chmod +x "${NET_CMD}" 2>/dev/null || true

update_option "status-left"
update_option "status-right"
