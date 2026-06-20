# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
