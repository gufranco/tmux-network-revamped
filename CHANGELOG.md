# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.4.0] - 2026-06-29

### Added

- `#{net_ssid}` shows the current Wi-Fi network name. macOS reads the
  `system_profiler SPAirPortDataType` current-network block, and Linux prefers
  `iwgetid -r` with an `iw dev link` fallback. Each probe is feature-detected
  and the token is empty when no tool reports a network.
- `#{net_online}` is now wired into the status interpolation, so the documented
  reachability token renders.

### Changed

- The heavy opt-in probes `#{net_ping}`, `#{net_public_ip}`, and `#{net_online}`
  refresh on their own intervals instead of the fast speed cadence. New options
  `@net_revamped_ping_interval`, `@net_revamped_public_ip_interval`, and
  `@net_revamped_online_interval` default to 15, 300, and 30 seconds, so speed
  stays responsive while a slow probe no longer fires on every sample.

## [1.3.0] - 2026-06-23

### Added

- `#{net_online}` reachability indicator. It probes over HTTP first, which keeps
  working on corporate networks that drop ICMP, and falls back to ping when curl
  is missing. Opt-in via `@net_revamped_online_enabled` (upstream
  tmux-online-status #16).

### Changed

- Reviewed the upstream tmux-net-speed and tmux-online-status issues. Throughput
  is measured on the single default-route interface, so bonded interfaces are
  never double-counted (#12), and the worker runs once per refresh with no
  process leak. Wi-Fi signal (#13) and macOS support are already shipped.

## [1.2.0] - 2026-06-20

### Added

- LAN IPv4 `#{net_ip}` of the active interface, from `ipconfig getifaddr` on
  macOS and `ip addr show` on Linux.
- Human VPN connection name `#{net_vpn_name}`, from `scutil --nc list` on macOS
  and `nmcli` on Linux. Both run as cheap local probes that always refresh.

## [1.1.0] - 2026-06-20

### Added

- VPN interface `#{net_vpn}` and established-connection count `#{net_connections}`,
  both from cheap local probes that always run.
- Wifi signal strength `#{net_wifi}` in dBm, from system_profiler on macOS and
  /proc/net/wireless on Linux.
- Opt-in `#{net_ping}` latency and `#{net_public_ip}`, gated behind options since
  they make network calls, and run only inside the background worker.

## [1.0.0] - 2026-06-19

### Added

- Network throughput placeholders: `#{net_download}`, `#{net_upload}`,
  `#{net_speed}`, `#{net_fg_color}`, `#{net_bg_color}`.
- Non-blocking design: counters are read in a background worker and the rate is
  read from a tmux user-option. The previous counters are stored in tmux options
  too, so the delta is computed without any temp file.
- macOS via `netstat -ib`, Linux via `/proc/net/dev`, with default-route
  interface detection.
- Configurable interface, interval, format, and color thresholds.
