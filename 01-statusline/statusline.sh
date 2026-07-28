#!/bin/sh
# Claude Code statusline: model · context % · 5h/7d usage % · conversation name,
# right-aligned against the screen edge.
# Portable: macOS, Linux, Windows (Git Bash). Requires jq.
#
# Claude Code re-runs this script on every turn, passing session state as JSON
# on stdin; whatever it prints becomes the bar at the bottom of the terminal.

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
conv_name=$(echo "$input" | jq -r '.session_name // ""')
model=$(echo "$input" | jq -r '.model.display_name // ""')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
five_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
week_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

# Compose the line: model, ctx, 5h, 7d, then the conversation name (cwd
# fallback on payloads without session_name) rightmost at the screen edge
line=""
[ -n "$model" ]    && line="$line$(printf "\033[0;36m%s\033[0m  " "$model")"
[ -n "$used_pct" ] && line="$line$(printf "ctx:\033[0;33m%.0f%%\033[0m  " "$used_pct")"
[ -n "$five_pct" ] && line="$line$(printf "5h:\033[0;35m%.0f%%\033[0m  " "$five_pct")"
[ -n "$week_pct" ] && line="$line$(printf "7d:\033[0;35m%.0f%%\033[0m  " "$week_pct")"
line="$line$(printf "\033[1;34m%s\033[0m" "${conv_name:-$cwd}")"

# Right-align by padding to the terminal width (COLUMNS is set in the spawned
# shell; tty fallback for other invocations). Visible width excludes the ANSI
# color codes. The TUI's statusline area is COLUMNS - 3 (2 cols left padding +
# 1 right margin; wider lines get ellipsis-truncated), so pad to that. The pad
# is prefixed with an SGR reset because Claude Code trims raw leading
# whitespace from statusline output — an ESC first character shields the
# spaces from that trim. If no width can be determined, render left-aligned.
cols=${COLUMNS:-$(stty size 2>/dev/null < /dev/tty | awk '{print $2}')}
esc=$(printf '\033')
visible=$(printf '%s' "$line" | sed "s/$esc\[[0-9;]*m//g" | wc -m | tr -d ' ')
pad=0
case "$cols" in '' | *[!0-9]*) : ;; *) pad=$(( cols - visible - 3 )) ;; esac
[ "$pad" -gt 0 ] && printf '\033[0m%*s' "$pad" ''
printf '%s\n' "$line"
