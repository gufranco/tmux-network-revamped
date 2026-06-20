#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/../../helpers.bash"

setup() {
  setup_test_environment
  unset _NETWORK_REVAMPED_RENDER_LOADED
  source "${BATS_TEST_DIRNAME}/../../../src/lib/network/render.sh"
}

teardown() {
  cleanup_test_environment
}

@test "render.sh - _net_level classifies by thresholds" {
  [[ "$(_net_level 10 100 1000)" == "low" ]]
  [[ "$(_net_level 500 100 1000)" == "medium" ]]
  [[ "$(_net_level 2000 100 1000)" == "high" ]]
}

@test "render.sh - _net_total_level converts bytes to a kilobyte tier" {
  [[ "$(_net_total_level 2097152)" == "high" ]]
  [[ "$(_net_total_level 153600)" == "medium" ]]
  [[ "$(_net_total_level 51200)" == "low" ]]
}

@test "render.sh - net_render_text echoes its input" {
  [[ "$(net_render_text "1.2MB/s")" == "1.2MB/s" ]]
}

@test "render.sh - net_render_speed joins download and upload" {
  [[ "$(net_render_speed "1.2MB/s" "0.3MB/s")" == "1.2MB/s 0.3MB/s" ]]
}

@test "render.sh - net_render_speed is empty when both are empty" {
  [[ -z "$(net_render_speed "" "")" ]]
}

@test "render.sh - net_render_speed honors a custom format" {
  set_tmux_option "@net_revamped_speed_format" "D %s U %s"
  [[ "$(net_render_speed "1K" "2K")" == "D 1K U 2K" ]]
}

@test "render.sh - net_render_fg is empty on cold start" {
  [[ -z "$(net_render_fg "")" ]]
}

@test "render.sh - net_render_fg returns the configured color" {
  set_tmux_option "@net_revamped_high_fg_color" "#[fg=red]"
  [[ "$(net_render_fg 2097152)" == "#[fg=red]" ]]
}

@test "render.sh - net_render_bg returns the configured color" {
  set_tmux_option "@net_revamped_low_bg_color" "#[bg=green]"
  [[ "$(net_render_bg 1024)" == "#[bg=green]" ]]
}

@test "render.sh - net_render_ping formats with default and custom" {
  [[ -z "$(net_render_ping "")" ]]
  [[ "$(net_render_ping 9)" == "9ms" ]]
  set_tmux_option "@net_revamped_ping_format" "ping %sms"
  [[ "$(net_render_ping 9)" == "ping 9ms" ]]
}
