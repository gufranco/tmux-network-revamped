#!/usr/bin/env bash
#
# network.sh: command dispatcher for tmux-network-revamped.
#
# Usage: network.sh download | upload | speed | fg_color | bg_color | refresh
#
# The worker reads interface counters, computes the rate against the previous
# counters held in tmux options, then stores the new counters for next time.

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

export CACHE_PREFIX="net_revamped"
export PLUGIN_LOG_NS="network-revamped"

# shellcheck source=/dev/null
source "${PLUGIN_DIR}/src/lib/utils/platform.sh"
# shellcheck source=/dev/null
source "${PLUGIN_DIR}/src/lib/tmux/tmux-ops.sh"
# shellcheck source=/dev/null
source "${PLUGIN_DIR}/src/lib/utils/cache.sh"
# shellcheck source=/dev/null
source "${PLUGIN_DIR}/src/lib/network/network.sh"
# shellcheck source=/dev/null
source "${PLUGIN_DIR}/src/lib/network/render.sh"

network_max_age() {
  get_tmux_option "@net_revamped_interval" "2"
}

net_interface() {
  local i
  i=$(get_tmux_option "@net_revamped_interface" "")
  [[ -n "${i}" ]] && { echo "${i}"; return 0; }
  default_iface
}

network_refresh() {
  local iface rx tx now prev_rx prev_tx prev_ts dt down up
  iface=$(net_interface)
  read -r rx tx <<< "$(read_counters "${iface}")"
  [[ "${rx}" =~ ^[0-9]+$ ]] || return 0

  now=$(date +%s)
  prev_rx=$(cache_get rx_raw)
  prev_tx=$(cache_get tx_raw)
  prev_ts=$(cache_get sample_ts)

  if [[ "${prev_ts}" =~ ^[0-9]+$ ]]; then
    dt=$(( now - prev_ts ))
    down=$(net_rate_compute "${rx}" "${prev_rx}" "${dt}")
    up=$(net_rate_compute "${tx}" "${prev_tx}" "${dt}")
  else
    down=0
    up=0
  fi

  cache_set download "$(net_format_rate "${down}")"
  cache_set upload "$(net_format_rate "${up}")"
  cache_set total "$(( down + up ))"
  cache_set rx_raw "${rx}"
  cache_set tx_raw "${tx}"
  cache_set sample_ts "${now}"

  # Cheap local probes always run; network-calling probes are opt-in.
  cache_set vpn "$(read_vpn)"
  cache_set connections "$(read_connections)"
  cache_set wifi "$(read_wifi)"
  cache_set ip "$(read_lan_ip)"
  cache_set vpn_name "$(read_vpn_name)"
  if [[ "$(get_tmux_option "@net_revamped_ping_enabled" "0")" == "1" ]]; then
    cache_set ping "$(read_ping)"
  fi
  if [[ "$(get_tmux_option "@net_revamped_public_ip_enabled" "0")" == "1" ]]; then
    cache_set public_ip "$(read_public_ip)"
  fi
  if [[ "$(get_tmux_option "@net_revamped_online_enabled" "0")" == "1" ]]; then
    cache_set online "$(read_online)"
  fi
  return 0
}

network_tick() {
  cache_refresh_if_stale download "$(network_max_age)" network_refresh
}

main() {
  local cmd="${1:-}"

  if [[ "${cmd}" == "refresh" ]]; then
    network_refresh
    return 0
  fi

  network_tick

  case "${cmd}" in
    download) net_render_text "$(cache_get download)" ;;
    upload)   net_render_text "$(cache_get upload)" ;;
    speed)    net_render_speed "$(cache_get download)" "$(cache_get upload)" ;;
    fg_color) net_render_fg "$(cache_get total)" ;;
    bg_color) net_render_bg "$(cache_get total)" ;;
    vpn)      net_render_text "$(cache_get vpn)" ;;
    vpn_name) net_render_text "$(cache_get vpn_name)" ;;
    ip)       net_render_text "$(cache_get ip)" ;;
    wifi)     net_render_wifi "$(cache_get wifi)" ;;
    connections) net_render_text "$(cache_get connections)" ;;
    ping)     net_render_ping "$(cache_get ping)" ;;
    public_ip) net_render_text "$(cache_get public_ip)" ;;
    online)   net_render_online "$(cache_get online)" ;;
    *)        return 0 ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
