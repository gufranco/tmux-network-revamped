# tmux-network-revamped

Network throughput in your tmux status bar, without ever blocking the status
render.

Speed is the change in interface byte counters between two refreshes. A detached
background worker reads the counters and computes the rate; the status line reads
the formatted result from a tmux server user-option and returns instantly. The
previous counters are kept in tmux options too, so the delta needs no temp file.

Built from
[tmux-plugin-template](https://github.com/gufranco/tmux-plugin-template).

## Placeholders

| Placeholder | Output |
|-------------|--------|
| `#{net_download}` | download rate, for example `1.2MB/s` |
| `#{net_upload}` | upload rate, for example `256.0KB/s` |
| `#{net_speed}` | download and upload together |
| `#{net_fg_color}` | foreground color for the current tier |
| `#{net_bg_color}` | background color for the current tier |

## Install

With [TPM](https://github.com/tmux-plugins/tpm):

```tmux
set -g @plugin 'gufranco/tmux-network-revamped'
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
| `@net_revamped_enable_logging` | `0` | set to `1` to log under `~/.tmux/network-revamped-logs` |

## Platform support

macOS reads `netstat -ib`, Linux reads `/proc/net/dev`. The default interface is
detected with `route` on macOS and `ip route` on Linux.

## License

[MIT](LICENSE), copyright Gustavo Franco.
