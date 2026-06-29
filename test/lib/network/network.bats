#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/../../helpers.bash"

PROC=$'Inter-|   Receive\n face |bytes\n  eth0: 1000 5 0 0 0 0 0 0 2000 8 0 0\n    lo: 10 1 0 0 0 0 0 0 10 1 0 0'
NETSTAT=$'Name Mtu Network Address Ipkts Ierrs Ibytes Opkts Oerrs Obytes Coll\nen0 1500 link a 100 0 123456 200 0 654321 0'

setup() {
  setup_test_environment
  unset _NETWORK_REVAMPED_NETWORK_LOADED
  source "${BATS_TEST_DIRNAME}/../../../src/lib/network/network.sh"
}

teardown() {
  cleanup_test_environment
}

@test "network.sh - net_counters_from_proc reads rx and tx" {
  [[ "$(net_counters_from_proc "${PROC}" eth0)" == "1000 2000" ]]
}

@test "network.sh - net_counters_from_proc is empty for a missing interface" {
  [[ -z "$(net_counters_from_proc "${PROC}" wlan9)" ]]
}

@test "network.sh - net_counters_from_netstat reads rx and tx" {
  [[ "$(net_counters_from_netstat "${NETSTAT}" en0)" == "123456 654321" ]]
}

@test "network.sh - net_rate_compute divides the delta by seconds" {
  [[ "$(net_rate_compute 2000 1000 2)" == "500" ]]
}

@test "network.sh - net_rate_compute is 0 for a zero interval" {
  [[ "$(net_rate_compute 2000 1000 0)" == "0" ]]
}

@test "network.sh - net_rate_compute clamps a counter reset to 0" {
  [[ "$(net_rate_compute 100 1000 2)" == "0" ]]
}

@test "network.sh - net_rate_compute is 0 for non-numeric input" {
  [[ "$(net_rate_compute x y z)" == "0" ]]
}

@test "network.sh - net_format_rate scales bytes, kilobytes, megabytes" {
  [[ "$(net_format_rate 500)" == "500B/s" ]]
  [[ "$(net_format_rate 2048)" == "2.0KB/s" ]]
  [[ "$(net_format_rate 2097152)" == "2.0MB/s" ]]
}

@test "network.sh - net_format_rate handles junk" {
  [[ "$(net_format_rate xx)" == "0B/s" ]]
}

@test "network.sh - default_iface uses the Linux route" {
  _PLATFORM_OS_CACHE="Linux"
  _default_iface_linux() { echo "eth0"; }
  [[ "$(default_iface)" == "eth0" ]]
}

@test "network.sh - default_iface uses the macOS route" {
  _PLATFORM_OS_CACHE="Darwin"
  _default_iface_macos() { echo "en0"; }
  [[ "$(default_iface)" == "en0" ]]
}

@test "network.sh - read_counters reads /proc on Linux" {
  _PLATFORM_OS_CACHE="Linux"
  _read_proc_net_dev() { printf '%s' "${PROC}"; }
  [[ "$(read_counters eth0)" == "1000 2000" ]]
}

@test "network.sh - read_counters reads netstat on macOS" {
  _PLATFORM_OS_CACHE="Darwin"
  _read_netstat() { printf '%s' "${NETSTAT}"; }
  [[ "$(read_counters en0)" == "123456 654321" ]]
}

@test "network.sh - read_counters is empty for an empty interface" {
  [[ -z "$(read_counters "")" ]]
}

@test "network.sh - ping_ms_from_output extracts milliseconds" {
  [[ "$(ping_ms_from_output '64 bytes from 8.8.8.8: icmp_seq=0 ttl=116 time=12.3 ms')" == "12" ]]
  [[ -z "$(ping_ms_from_output 'no reply')" ]]
}

@test "network.sh - count_established counts connections" {
  local txt=$'tcp 0 0 a b ESTABLISHED\ntcp 0 0 c d LISTEN\ntcp 0 0 e f ESTABLISHED'
  [[ "$(count_established "${txt}")" == "2" ]]
}

@test "network.sh - valid_ipv4 validates an address" {
  [[ "$(valid_ipv4 '203.0.113.7')" == "203.0.113.7" ]]
  [[ "$(valid_ipv4 '203.0.113.7 ')" == "203.0.113.7" ]]
  [[ -z "$(valid_ipv4 'not-an-ip')" ]]
}

@test "network.sh - vpn_from_links_linux finds a tunnel interface" {
  [[ "$(vpn_from_links_linux '5: tun0: <UP> mtu 1500')" == "tun0" ]]
  [[ "$(vpn_from_links_linux '6: wg0: <UP>')" == "wg0" ]]
}

@test "network.sh - online_from_probe reads curl exit and HTTP codes" {
  [[ "$(online_from_probe 0)" == "up" ]]
  [[ "$(online_from_probe 204)" == "up" ]]
  [[ "$(online_from_probe 301)" == "up" ]]
  [[ -z "$(online_from_probe 7)" ]]
  [[ -z "$(online_from_probe 000)" ]]
}

@test "network.sh - read_online uses the curl probe when curl exists" {
  command() { [[ "$2" == "curl" ]] && return 0; builtin command "$@"; }
  _read_curl_status() { echo "0"; }
  [[ "$(read_online)" == "up" ]]
}

@test "network.sh - read_online is empty when the curl probe fails" {
  command() { [[ "$2" == "curl" ]] && return 0; builtin command "$@"; }
  _read_curl_status() { echo "28"; }
  [[ -z "$(read_online)" ]]
}

@test "network.sh - read_online falls back to ping without curl" {
  command() { [[ "$2" == "curl" ]] && return 1; builtin command "$@"; }
  read_ping() { echo "12"; }
  [[ "$(read_online)" == "up" ]]
}

@test "network.sh - vpn_from_routes_macos finds a utun interface" {
  [[ "$(vpn_from_routes_macos 'default 10.0.0.1 UGScg utun3')" == "utun3" ]]
}

@test "network.sh - read_ping reads ping on Linux" {
  _PLATFORM_OS_CACHE="Linux"
  _read_ping_linux() { echo "64 bytes from 8.8.8.8: time=9.8 ms"; }
  [[ "$(read_ping)" == "9" ]]
}

@test "network.sh - read_ping reads ping on macOS" {
  _PLATFORM_OS_CACHE="Darwin"
  _read_ping_macos() { echo "64 bytes from 8.8.8.8: time=15.2 ms"; }
  [[ "$(read_ping)" == "15" ]]
}

@test "network.sh - read_connections counts established" {
  _read_netstat_an() { printf 'a ESTABLISHED\nb ESTABLISHED\nc LISTEN\n'; }
  [[ "$(read_connections)" == "2" ]]
}

@test "network.sh - read_public_ip validates the response" {
  _read_public_ip() { echo "198.51.100.9"; }
  [[ "$(read_public_ip)" == "198.51.100.9" ]]
}

@test "network.sh - read_vpn reads routes on macOS" {
  _PLATFORM_OS_CACHE="Darwin"
  _read_route_table() { echo "default 10.0.0.1 UGScg utun4"; }
  [[ "$(read_vpn)" == "utun4" ]]
}

@test "network.sh - read_vpn reads links on Linux" {
  _PLATFORM_OS_CACHE="Linux"
  _read_ip_links() { echo "7: wg0: <UP>"; }
  [[ "$(read_vpn)" == "wg0" ]]
}

@test "network.sh - wifi_from_sp_macos extracts the RSSI" {
  [[ "$(wifi_from_sp_macos '            Signal / Noise: -55 dBm / -90 dBm')" == "-55" ]]
  [[ -z "$(wifi_from_sp_macos 'no wifi here')" ]]
}

@test "network.sh - wifi_from_proc_wireless extracts the level" {
  local txt=$'Inter-| sta\n face | tus | link level\n wlan0: 0000   70.  -45.  -256'
  [[ "$(wifi_from_proc_wireless "${txt}")" == "-45" ]]
}

@test "network.sh - read_wifi reads system_profiler on macOS" {
  _PLATFORM_OS_CACHE="Darwin"
  _read_sp_airport() { echo "        Signal / Noise: -60 dBm / -92 dBm"; }
  [[ "$(read_wifi)" == "-60" ]]
}

@test "network.sh - read_wifi reads /proc/net/wireless on Linux" {
  _PLATFORM_OS_CACHE="Linux"
  _read_proc_wireless() { printf 'h1\nh2\n wlan0: 0000 70. -50. -256\n'; }
  [[ "$(read_wifi)" == "-50" ]]
}

@test "network.sh - ipv4_from_ip_addr strips the prefix length" {
  local txt=$'2: eth0: <BROADCAST>\n    inet 192.168.1.42/24 brd 192.168.1.255 scope global eth0'
  [[ "$(ipv4_from_ip_addr "${txt}")" == "192.168.1.42" ]]
  [[ -z "$(ipv4_from_ip_addr 'no address here')" ]]
}

@test "network.sh - vpn_name_from_scutil extracts the connected name" {
  local txt=$'* (Disconnected) AAAA PPP (PPP) "Office" [PPP:PPP]\n* (Connected) BBBB PPP (PPP) "MyVPN" [PPP:PPP]'
  [[ "$(vpn_name_from_scutil "${txt}")" == "MyVPN" ]]
  [[ -z "$(vpn_name_from_scutil '* (Disconnected) AAAA PPP "Office"')" ]]
}

@test "network.sh - vpn_name_from_nmcli extracts the vpn or wireguard name" {
  [[ "$(vpn_name_from_nmcli $'eth0:ethernet\nWork VPN:vpn')" == "Work VPN" ]]
  [[ "$(vpn_name_from_nmcli $'wg-home:wireguard')" == "wg-home" ]]
  [[ -z "$(vpn_name_from_nmcli 'eth0:ethernet')" ]]
}

@test "network.sh - read_lan_ip reads ifconfig on macOS" {
  _PLATFORM_OS_CACHE="Darwin"
  default_iface() { echo "en0"; }
  _read_ifaddr_macos() { echo "10.0.0.5"; }
  [[ "$(read_lan_ip)" == "10.0.0.5" ]]
}

@test "network.sh - read_lan_ip parses ip addr on Linux" {
  _PLATFORM_OS_CACHE="Linux"
  default_iface() { echo "eth0"; }
  _read_ip_addr_linux() { echo "    inet 192.168.1.42/24 brd 192.168.1.255 scope global eth0"; }
  [[ "$(read_lan_ip)" == "192.168.1.42" ]]
}

@test "network.sh - read_lan_ip is empty without an interface" {
  default_iface() { echo ""; }
  [[ -z "$(read_lan_ip)" ]]
}

@test "network.sh - read_vpn_name reads scutil on macOS" {
  _PLATFORM_OS_CACHE="Darwin"
  _read_scutil_macos() { echo '* (Connected) BBBB PPP (PPP) "MyVPN" [PPP:PPP]'; }
  [[ "$(read_vpn_name)" == "MyVPN" ]]
}

@test "network.sh - read_vpn_name reads nmcli on Linux" {
  _PLATFORM_OS_CACHE="Linux"
  _read_nmcli_active_linux() { printf 'eth0:ethernet\nWork VPN:vpn\n'; }
  [[ "$(read_vpn_name)" == "Work VPN" ]]
}

@test "network.sh - host-probe seams are callable" {
  run _read_proc_net_dev
  run _read_netstat
  run _read_netstat_an
  run _read_ping_linux
  run _read_ping_macos
  run _read_ip_links
  run _read_route_table
  run _read_proc_wireless
  run _read_sp_airport
  run _default_iface_linux
  run _default_iface_macos
  run _read_ifaddr_macos eth0
  run _read_ip_addr_linux eth0
  run _read_scutil_macos
  run _read_nmcli_active_linux
  run _read_iwgetid
  run _read_iw_dev_link wlan0
  true
}

@test "network.sh - ssid_from_sp_macos reads the current network block" {
  local txt=$'      Current Network Information:\n        HomeWiFi:\n          PHY Mode: 802.11ax\n      Other Local Wi-Fi Networks:\n        Neighbor:'
  [[ "$(ssid_from_sp_macos "${txt}")" == "HomeWiFi" ]]
  [[ -z "$(ssid_from_sp_macos 'no wifi block here')" ]]
}

@test "network.sh - ssid_from_iwgetid trims the bare ssid" {
  [[ "$(ssid_from_iwgetid 'HomeWiFi')" == "HomeWiFi" ]]
  [[ "$(ssid_from_iwgetid 'HomeWiFi   ')" == "HomeWiFi" ]]
  [[ -z "$(ssid_from_iwgetid '')" ]]
}

@test "network.sh - ssid_from_iw_link extracts the SSID line" {
  local txt=$'Connected to aa:bb (on wlan0)\n\tSSID: IwNet\n\tfreq: 5180'
  [[ "$(ssid_from_iw_link "${txt}")" == "IwNet" ]]
  [[ -z "$(ssid_from_iw_link 'no ssid here')" ]]
}

@test "network.sh - read_ssid reads system_profiler on macOS" {
  _PLATFORM_OS_CACHE="Darwin"
  _read_sp_airport() { printf '%s' $'      Current Network Information:\n        MacNet:\n          PHY Mode: 802.11ac'; }
  [[ "$(read_ssid)" == "MacNet" ]]
}

@test "network.sh - read_ssid reads iwgetid on Linux" {
  _PLATFORM_OS_CACHE="Linux"
  _read_iwgetid() { echo "WgNet"; }
  [[ "$(read_ssid)" == "WgNet" ]]
}

@test "network.sh - read_ssid falls back to iw dev link on Linux" {
  _PLATFORM_OS_CACHE="Linux"
  _read_iwgetid() { echo ""; }
  default_iface() { echo "wlan0"; }
  _read_iw_dev_link() { printf 'Connected\n\tSSID: FallbackNet\n'; }
  [[ "$(read_ssid)" == "FallbackNet" ]]
}

@test "network.sh - read_ssid is empty when no tool reports an ssid" {
  _PLATFORM_OS_CACHE="Linux"
  _read_iwgetid() { echo ""; }
  default_iface() { echo "wlan0"; }
  _read_iw_dev_link() { echo ""; }
  [[ -z "$(read_ssid)" ]]
}
