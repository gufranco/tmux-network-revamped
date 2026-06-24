#!/usr/bin/env bash
#
# render.sh: map cached network values to text, an icon, and colors.

[[ -n "${_NETWORK_REVAMPED_RENDER_LOADED:-}" ]] && return 0
_NETWORK_REVAMPED_RENDER_LOADED=1

_NET_RENDER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${_NET_RENDER_DIR}/../tmux/tmux-ops.sh"

_net_level() {
  local v="${1%%.*}" med="${2}" high="${3}"
  [[ "${v}" =~ ^-?[0-9]+$ ]] || v=0
  if (( v >= high )); then
    echo "high"
  elif (( v >= med )); then
    echo "medium"
  else
    echo "low"
  fi
}

# _net_total_level TOTAL_BPS -> tier from KB/s thresholds.
_net_total_level() {
  local kbps=$(( ${1:-0} / 1024 ))
  _net_level "${kbps}" "$(get_tmux_option "@net_revamped_medium_thresh" "100")" \
    "$(get_tmux_option "@net_revamped_high_thresh" "1000")"
}

net_render_text() {
  echo "${1}"
}

net_render_speed() {
  local down="${1}" up="${2}"
  [[ -z "${down}" && -z "${up}" ]] && { echo ""; return 0; }
  local fmt
  fmt=$(get_tmux_option "@net_revamped_speed_format" "%s %s")
  # shellcheck disable=SC2059
  printf "${fmt}" "${down}" "${up}"
}

net_render_fg() {
  [[ -z "${1}" ]] && { echo ""; return 0; }
  get_tmux_option "@net_revamped_$(_net_total_level "${1}")_fg_color" ""
}

net_render_bg() {
  [[ -z "${1}" ]] && { echo ""; return 0; }
  get_tmux_option "@net_revamped_$(_net_total_level "${1}")_bg_color" ""
}

net_render_ping() {
  [[ -z "${1}" ]] && { echo ""; return 0; }
  local fmt
  fmt=$(get_tmux_option "@net_revamped_ping_format" "%sms")
  # shellcheck disable=SC2059
  printf "${fmt}" "${1}"
}

net_render_wifi() {
  [[ -z "${1}" ]] && { echo ""; return 0; }
  local fmt
  fmt=$(get_tmux_option "@net_revamped_wifi_format" "%sdBm")
  # shellcheck disable=SC2059
  printf "${fmt}" "${1}"
}

# net_render_online VALUE -> a configurable label for the reachability state.
# Defaults are plain text so the status bar stays readable without a glyph font.
net_render_online() {
  if [[ "${1}" == "up" ]]; then
    get_tmux_option "@net_revamped_online_up_text" "on"
  else
    get_tmux_option "@net_revamped_online_down_text" "off"
  fi
}

export -f _net_level
export -f _net_total_level
export -f net_render_online
export -f net_render_text
export -f net_render_ping
export -f net_render_wifi
export -f net_render_speed
export -f net_render_fg
export -f net_render_bg
