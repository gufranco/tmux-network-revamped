<div align="center">

<h1>tmux-network-revamped</h1>

**Network throughput in your tmux status bar, without ever blocking the render.**

[![Tests](https://github.com/tmux-revamped/tmux-network-revamped/actions/workflows/tests.yml/badge.svg)](https://github.com/tmux-revamped/tmux-network-revamped/actions/workflows/tests.yml) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE) [![Version](https://img.shields.io/badge/version-1.3.0-blue.svg)](CHANGELOG.md)

</div>

**12** placeholders · **2** platforms · **108** tests · **95%+** coverage

Surfaces network throughput, VPN interface and name, LAN IP, established connections, ping latency, public IP, and wifi signal in your tmux status bar. A detached background worker reads interface byte counters and computes the rate; the status line reads the formatted result from a tmux server user-option and returns instantly. Previous counters live in tmux options too, so the delta needs no temp file.

Built from [tmux-plugin-template](https://github.com/tmux-revamped/tmux-plugin-template).

<table>
<tr>
<td><strong>Non-blocking</strong><br/>The status line reads a cached value from a tmux user-option and returns instantly.</td>
<td><strong>No temp files</strong><br/>Previous counters live in tmux options, so the rate delta needs no scratch file.</td>
</tr>
<tr>
<td><strong>Cross-platform</strong><br/>macOS and Linux on both Intel and ARM with built-in tools, no extra package.</td>
<td><strong>Tested</strong><br/>108 [bats](https://github.com/bats-core/bats-core) tests hold 95%+ coverage across every probe.</td>
</tr>
</table>

## Placeholders

| Placeholder | Output |
|-------------|--------|
| `#{net_download}` | download rate, for example `1.2MB/s` |
| `#{net_upload}` | upload rate, for example `256.0KB/s` |
| `#{net_speed}` | download and upload together |
| `#{net_fg_color}` | foreground color for the current tier |
| `#{net_bg_color}` | background color for the current tier |
| `#{net_vpn}` | active VPN interface, empty when none |
| `#{net_vpn_name}` | human VPN connection name, needs `scutil` on macOS or `nmcli` on Linux |
| `#{net_ip}` | LAN IPv4 of the active interface |
| `#{net_connections}` | count of established connections |
| `#{net_ping}` | latency to 8.8.8.8, opt-in |
| `#{net_public_ip}` | public IPv4 address, opt-in |
| `#{net_wifi}` | wifi signal strength in dBm, for example `-55dBm` |
| `#{net_online}` | reachability state, `on` or `off`, opt-in |

## Install

With [TPM](https://github.com/tmux-plugins/tpm):

```tmux
set -g @plugin 'tmux-revamped/tmux-network-revamped'
set -g status-right '#{net_fg_color}#{net_speed}'
```

Press `prefix + I` to install.

## Configuration

| Option | Default | Meaning |
|--------|---------|---------|
| `@net_revamped_interface` | auto | the interface to measure; empty auto-detects the default route |
| `@net_revamped_interval` | `2` | seconds between samples, also the rate window |
| `@net_revamped_speed_format` | `%s %s` | format for download and upload |
| `@net_revamped_medium_thresh` | `100` | total kilobytes per second for the medium tier |
| `@net_revamped_high_thresh` | `1000` | total kilobytes per second for the high tier |
| `@net_revamped_{low,medium,high}_{fg,bg}_color` | empty | tier colors |
| `@net_revamped_ping_enabled` | `0` | set to `1` to probe ping latency (makes a network call) |
| `@net_revamped_ping_format` | `%sms` | format for the ping latency |
| `@net_revamped_public_ip_enabled` | `0` | set to `1` to fetch the public IP (makes a network call) |
| `@net_revamped_wifi_format` | `%sdBm` | format for the wifi signal |
| `@net_revamped_online_enabled` | `0` | set to `1` to probe internet reachability over HTTP, which works where corporate firewalls drop ICMP (makes a network call) |
| `@net_revamped_online_up_text` | `on` | label shown when reachable |
| `@net_revamped_online_down_text` | `off` | label shown when not reachable |
| `@net_revamped_enable_logging` | `0` | set to `1` to log under `~/.tmux/network-revamped-logs` |

## Theme color suggestions

The defaults use the 16 ANSI color names, which the active terminal theme remaps, so the tiers match any theme out of the box. For exact hex values, copy one block below. Low traffic maps to green, medium to yellow, and high to red.

### Catppuccin Mocha

```tmux
set -g @net_revamped_low_fg_color '#[fg=#a6e3a1]'
set -g @net_revamped_medium_fg_color '#[fg=#f9e2af]'
set -g @net_revamped_high_fg_color '#[fg=#f38ba8]'
```

### Dracula

```tmux
set -g @net_revamped_low_fg_color '#[fg=#50fa7b]'
set -g @net_revamped_medium_fg_color '#[fg=#f1fa8c]'
set -g @net_revamped_high_fg_color '#[fg=#ff5555]'
```

### Nord

```tmux
set -g @net_revamped_low_fg_color '#[fg=#a3be8c]'
set -g @net_revamped_medium_fg_color '#[fg=#ebcb8b]'
set -g @net_revamped_high_fg_color '#[fg=#bf616a]'
```

### Gruvbox Dark

```tmux
set -g @net_revamped_low_fg_color '#[fg=#b8bb26]'
set -g @net_revamped_medium_fg_color '#[fg=#fabd2f]'
set -g @net_revamped_high_fg_color '#[fg=#fb4934]'
```

### Tokyo Night

```tmux
set -g @net_revamped_low_fg_color '#[fg=#9ece6a]'
set -g @net_revamped_medium_fg_color '#[fg=#e0af68]'
set -g @net_revamped_high_fg_color '#[fg=#f7768e]'
```

### Solarized Dark

```tmux
set -g @net_revamped_low_fg_color '#[fg=#859900]'
set -g @net_revamped_medium_fg_color '#[fg=#b58900]'
set -g @net_revamped_high_fg_color '#[fg=#dc322f]'
```

## Support by platform and architecture

Works on every supported platform and architecture with built-in tools, no extra
package required. macOS (Intel and Apple Silicon) reads `netstat -ib`; Linux
(x86_64 and arm64) reads `/proc/net/dev`. The default interface is detected with
`route` on macOS and `ip route` on Linux.

Wifi signal reads `system_profiler SPAirPortDataType` on macOS, which works without
the `airport` binary Apple removed in macOS 14.4, and `/proc/net/wireless` on
Linux. It reports RSSI in dBm; closer to zero is stronger.

## Development

```bash
make test      # run the bats suite
make lint      # shellcheck every script
make coverage  # run the suite under kcov
```

## License

[MIT](LICENSE), copyright Gustavo Franco.
