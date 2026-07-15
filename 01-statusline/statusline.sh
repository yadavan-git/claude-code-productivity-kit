#!/bin/sh
# Claude Code statusline: user · directory · model · context % · 5h/7d usage %.
# Portable: macOS, Linux, Windows (Git Bash). Requires jq.
#
# Claude Code re-runs this script on every turn, passing session state as JSON
# on stdin; whatever it prints becomes the bar at the bottom of the terminal.

input=$(cat)

user=$(whoami)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
model=$(echo "$input" | jq -r '.model.display_name // ""')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
five_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
week_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

# Username and directory
printf "\033[1;32m%s\033[0m:\033[1;34m%s\033[0m" "$user" "$cwd"

# Model name
if [ -n "$model" ]; then
  printf "  \033[0;36m%s\033[0m" "$model"
fi

# Context window usage
if [ -n "$used_pct" ]; then
  printf "  ctx:\033[0;33m%.0f%%\033[0m" "$used_pct"
fi

# 5-hour session limit
if [ -n "$five_pct" ]; then
  printf "  5h:\033[0;35m%.0f%%\033[0m" "$five_pct"
fi

# 7-day weekly limit
if [ -n "$week_pct" ]; then
  printf "  7d:\033[0;35m%.0f%%\033[0m" "$week_pct"
fi

printf "\n"
