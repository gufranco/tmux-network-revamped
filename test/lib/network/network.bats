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
