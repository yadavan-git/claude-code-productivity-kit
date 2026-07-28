#!/bin/sh
input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
conv_name=$(echo "$input" | jq -r '.session_name // ""')
model=$(echo "$input" | jq -r '.model.display_name // ""')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
five_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
week_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
five_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
week_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

# ---- Persist rate-limit data for desktop widget ----
# The statusline payload's rate-limit numbers are only as fresh as THIS session's
# last rate-limited API exchange — right after a session starts or /compacts it can
# report a value that's several minutes stale, and occasionally a render carries no
# rate-limit data at all. Since every session overwrites the shared file below, a
# laggy/empty render can clobber a good reading (observed in practice: a post-/compact
# render can write a stale lower value, and an empty render can write 0%). Two guards:
#  (a) empty new reading -> keep the previously-persisted figures, don't write 0;
#  (b) new 5h reading sharply LOWER than what was just persisted, no 5h reset crossed,
#      and the prior write was recent (<10 min) -> keep the prior figures (the 5h
#      window doesn't fall like that except at a reset).
#      Two escapes so (b) can't pin a stale-high figure forever: it is BYPASSED when the
#      5h resets_at CHANGES vs what's persisted (a new window / account switch -> the drop
#      is real, not a glitch), and when it does hold it keeps the HELD reading's ORIGINAL
#      updated_at (not "now") so the <10-min freshness check actually expires.
# Percentages are floored to integers on write (the payload sometimes sends floats
# like 55.00000000000001). Fail-open: a non-integer/parse hiccup skips guard (b).
_rl_file="$HOME/.claude/usage-status.json"
_rl_ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
_ts_out=$_rl_ts   # timestamp to persist; a held reading keeps its ORIGINAL time (guards below)

_five_out=${five_pct:-}
_week_out=${week_pct:-}
_five_reset_out=${five_reset:-}
_week_reset_out=${week_reset:-}
_five_int=${five_pct%%.*}   # integer view for the comparison below

if [ -f "$_rl_file" ]; then
  _p_five=$(jq -r '.five_hour_pct       // empty' "$_rl_file" 2>/dev/null)
  _p_week=$(jq -r '.seven_day_pct       // empty' "$_rl_file" 2>/dev/null)
  _p_ts=$(jq   -r '.updated_at          // empty' "$_rl_file" 2>/dev/null)
  _p_fr=$(jq   -r '.five_hour_resets_at // empty' "$_rl_file" 2>/dev/null)
  _p_wr=$(jq   -r '.seven_day_resets_at // empty' "$_rl_file" 2>/dev/null)
  _p_five_int=${_p_five%%.*}
  _p_fr_int=${_p_fr%%.*}
  if [ -z "$five_pct" ] && [ -n "$_p_five" ]; then
    # (a) this render carried no rate-limit data -> keep prev, don't clobber with 0
    _five_out=$_p_five; [ -n "$_p_week" ] && _week_out=$_p_week
    _five_reset_out=$_p_fr; _week_reset_out=$_p_wr
    _ts_out=${_p_ts:-$_rl_ts}   # keep the held reading's original time
  elif [ -n "$five_pct" ] && [ -n "$_p_five" ]; then
    # (b) backward-jump staleness guard
    _now_e=$(date -u +%s 2>/dev/null)
    _p_e=$(date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$_p_ts" +%s 2>/dev/null)
    _skip_guard=0
    for _v in "$_five_int" "$_p_five_int" "$_now_e" "$_p_e"; do
      case "$_v" in '' | *[!0-9]*) _skip_guard=1 ;; esac
    done
    if [ "$_skip_guard" -eq 0 ]; then
      _age=$(( _now_e - _p_e ))
      _crossed=0
      case "$_p_fr_int" in '' | *[!0-9]*) : ;; *) [ "$_now_e" -ge "$_p_fr_int" ] && _crossed=1 ;; esac
      # A changed 5h resets_at => a new window / account switch => the drop is real, don't hold.
      _reset_changed=0
      [ -n "$five_reset" ] && [ -n "$_p_fr" ] && [ "$five_reset" != "$_p_fr" ] && _reset_changed=1
      if [ "$_age" -ge 0 ] && [ "$_age" -lt 600 ] && [ "$_crossed" -eq 0 ] && [ "$_reset_changed" -eq 0 ] && [ "$_five_int" -lt $(( _p_five_int - 3 )) ]; then
        _five_out=$_p_five; [ -n "$_p_week" ] && _week_out=$_p_week
        _five_reset_out=$_p_fr; _week_reset_out=$_p_wr
        _ts_out=${_p_ts:-$_rl_ts}   # keep the held reading's original time so freshness can expire
      fi
    fi
  fi
fi

_rl_json=$(jq -n \
  --arg five       "${_five_out:-0}" \
  --arg week       "${_week_out:-0}" \
  --arg ctx        "${used_pct:-0}" \
  --arg model      "${model:-unknown}" \
  --arg ts         "$_ts_out" \
  --arg five_reset "${_five_reset_out:-}" \
  --arg week_reset "${_week_reset_out:-}" \
  '{
    five_hour_pct:        (try ($five | tonumber | floor) catch 0),
    seven_day_pct:        (try ($week | tonumber | floor) catch 0),
    context_pct:          (try ($ctx  | tonumber | floor) catch 0),
    model:                $model,
    updated_at:           $ts,
    five_hour_resets_at:  (if $five_reset == "" then null else (try ($five_reset | tonumber) catch null) end),
    seven_day_resets_at:  (if $week_reset == "" then null else (try ($week_reset | tonumber) catch null) end)
  }')
printf '%s\n' "$_rl_json" > "${_rl_file}.$$.tmp" && mv "${_rl_file}.$$.tmp" "$_rl_file"

# ---- Append history row (throttled to once per minute) ----
_rl_history="$HOME/.claude/usage-history.jsonl"
if [ -z "$(find "$_rl_history" -mmin -1 2>/dev/null)" ]; then
  printf '%s\n' "$_rl_json" >> "$_rl_history"
fi
# ---- End persist block ----

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
