#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/../../helpers.bash"

setup() {
  setup_test_environment
  unset _NETWORK_REVAMPED_NETWORK_LOADED _NETWORK_REVAMPED_RENDER_LOADED
  export CACHE_SYNC=1
  source "${BATS_TEST_DIRNAME}/../../../src/network.sh"
  default_iface() { echo "eth0"; }
  NET_RX=1000
  NET_TX=2000
  read_counters() { echo "${NET_RX} ${NET_TX}"; }
  read_vpn() { echo "wg0"; }
  read_connections() { echo "12"; }
  read_ping() { echo "9"; }
  read_public_ip() { echo "198.51.100.9"; }
  read_wifi() { echo "-55"; }
  read_ssid() { echo "HomeWiFi"; }
  read_lan_ip() { echo "192.168.1.42"; }
  read_vpn_name() { echo "Work VPN"; }
  read_online() { echo "up"; }
}

teardown() {
  cleanup_test_environment
}

@test "network.sh dispatcher - functions are defined" {
  function_exists main
  function_exists network_refresh
  function_exists network_tick
  function_exists network_max_age
  function_exists net_interface
  function_exists net_probe_max_age
}

@test "network.sh dispatcher - network_max_age default is 2" {
  [[ "$(network_max_age)" == "2" ]]
}

@test "network.sh dispatcher - net_interface honors the option" {
  set_tmux_option "@net_revamped_interface" "wlan0"
  [[ "$(net_interface)" == "wlan0" ]]
}

@test "network.sh dispatcher - net_interface auto-detects by default" {
  [[ "$(net_interface)" == "eth0" ]]
}

@test "network.sh dispatcher - first sample reports zero and stores counters" {
  export MOCK_EPOCH=1000
  network_refresh
  [[ "$(cache_get download)" == "0B/s" ]]
  [[ "$(cache_get rx_raw)" == "1000" ]]
  [[ "$(cache_get sample_ts)" == "1000" ]]
}

@test "network.sh dispatcher - second sample computes the rate" {
  export MOCK_EPOCH=1000
  network_refresh
  NET_RX=3048
  NET_TX=2000
  export MOCK_EPOCH=1002
  network_refresh
  [[ "$(cache_get download)" == "1.0KB/s" ]]
  [[ "$(cache_get upload)" == "0B/s" ]]
}

@test "network.sh dispatcher - refresh keeps the last value when unreadable" {
  cache_set download "9.9MB/s"
  read_counters() { echo ""; }
  network_refresh
  [[ "$(cache_get download)" == "9.9MB/s" ]]
}

@test "network.sh dispatcher - download renders the cached value" {
  export MOCK_EPOCH=1000
  run main download
  [[ "${output}" == "0B/s" ]]
}

@test "network.sh dispatcher - speed joins download and upload" {
  export MOCK_EPOCH=1000
  main refresh
  run main speed
  [[ "${output}" == "0B/s 0B/s" ]]
}

@test "network.sh dispatcher - refresh caches vpn, connections, wifi" {
  export MOCK_EPOCH=1000
  network_refresh
  [[ "$(cache_get vpn)" == "wg0" ]]
  [[ "$(cache_get connections)" == "12" ]]
  [[ "$(cache_get wifi)" == "-55" ]]
}

@test "network.sh dispatcher - refresh caches ip and vpn_name" {
  export MOCK_EPOCH=1000
  network_refresh
  [[ "$(cache_get ip)" == "192.168.1.42" ]]
  [[ "$(cache_get vpn_name)" == "Work VPN" ]]
}

@test "network.sh dispatcher - ip and vpn_name subcommands render" {
  cache_set ip "192.168.1.42"
  cache_set vpn_name "Work VPN"
  run main ip
  [[ "${output}" == "192.168.1.42" ]]
  run main vpn_name
  [[ "${output}" == "Work VPN" ]]
}

@test "network.sh dispatcher - wifi subcommand renders the cache" {
  cache_set wifi "-55"
  run main wifi
  [[ "${output}" == "-55dBm" ]]
}

@test "network.sh dispatcher - ping and public_ip are opt-in" {
  export MOCK_EPOCH=1000
  network_refresh
  [[ -z "$(cache_get ping)" ]]
  set_tmux_option "@net_revamped_ping_enabled" "1"
  set_tmux_option "@net_revamped_public_ip_enabled" "1"
  network_refresh
  [[ "$(cache_get ping)" == "9" ]]
  [[ "$(cache_get public_ip)" == "198.51.100.9" ]]
}

@test "network.sh dispatcher - vpn, connections, ping subcommands render" {
  cache_set vpn "wg0"
  cache_set connections "12"
  cache_set ping "9"
  run main vpn
  [[ "${output}" == "wg0" ]]
  run main connections
  [[ "${output}" == "12" ]]
  run main ping
  [[ "${output}" == "9ms" ]]
  cache_set public_ip "198.51.100.9"
  run main public_ip
  [[ "${output}" == "198.51.100.9" ]]
}

@test "network.sh dispatcher - online is opt-in and renders the cache" {
  export MOCK_EPOCH=1000
  network_refresh
  [[ -z "$(cache_get online)" ]]
  set_tmux_option "@net_revamped_online_enabled" "1"
  network_refresh
  [[ "$(cache_get online)" == "up" ]]
  run main online
  [[ "${output}" == "on" ]]
}

@test "network.sh dispatcher - unknown subcommand produces no output" {
  run main bogus
  [[ -z "${output}" ]]
}

@test "network.sh dispatcher - net_probe_max_age default and option" {
  [[ "$(net_probe_max_age ping 15)" == "15" ]]
  set_tmux_option "@net_revamped_ping_interval" "42"
  [[ "$(net_probe_max_age ping 15)" == "42" ]]
}

@test "network.sh dispatcher - refresh caches ssid" {
  export MOCK_EPOCH=1000
  network_refresh
  [[ "$(cache_get ssid)" == "HomeWiFi" ]]
}

@test "network.sh dispatcher - ssid subcommand renders the cache" {
  cache_set ssid "HomeWiFi"
  run main ssid
  [[ "${output}" == "HomeWiFi" ]]
}

@test "network.sh dispatcher - a heavy probe keeps its own slow interval" {
  set_tmux_option "@net_revamped_ping_enabled" "1"
  set_tmux_option "@net_revamped_ping_interval" "60"
  export MOCK_EPOCH=1000
  network_refresh
  [[ "$(cache_get ping)" == "9" ]]
  read_ping() { echo "99"; }
  export MOCK_EPOCH=1010
  network_refresh
  [[ "$(cache_get ping)" == "9" ]]
  export MOCK_EPOCH=1100
  network_refresh
  [[ "$(cache_get ping)" == "99" ]]
}

@test "network.sh dispatcher - public_ip refreshes only after its interval" {
  set_tmux_option "@net_revamped_public_ip_enabled" "1"
  set_tmux_option "@net_revamped_public_ip_interval" "300"
  export MOCK_EPOCH=1000
  network_refresh
  [[ "$(cache_get public_ip)" == "198.51.100.9" ]]
  read_public_ip() { echo "203.0.113.1"; }
  export MOCK_EPOCH=1100
  network_refresh
  [[ "$(cache_get public_ip)" == "198.51.100.9" ]]
  export MOCK_EPOCH=1400
  network_refresh
  [[ "$(cache_get public_ip)" == "203.0.113.1" ]]
}

@test "network.sh dispatcher - upload renders the cached rate" {
  export MOCK_EPOCH=1000
  run main upload
  [ "$status" -eq 0 ]
  [[ "$output" == "0B/s" ]]
}

@test "network.sh dispatcher - fg_color routes without error" {
  export MOCK_EPOCH=1000
  run main fg_color
  [ "$status" -eq 0 ]
}

@test "network.sh dispatcher - bg_color routes without error" {
  export MOCK_EPOCH=1000
  run main bg_color
  [ "$status" -eq 0 ]
}
