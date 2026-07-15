#!/bin/bash

# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideDisablePlugin>true</swiftbar.hideDisablePlugin>

STATUS_FILE="$HOME/.claude/usage-status.json"

# ---- Helper: color for a percentage value ----
color_for_pct() {
  local pct=$1
  if (( $(echo "$pct < 50" | bc -l) )); then
    echo "#ffffff"   # white
  elif (( $(echo "$pct < 80" | bc -l) )); then
    echo "#eab308"   # yellow / amber
  else
    echo "#ef4444"   # red
  fi
}

# ---- Helper: humanize a positive second-delta as "Nm" / "Nh Mm" / "Nd" ----
rel_time() {
  local delta=$1
  if [ "$delta" -lt 60 ]; then
    echo "<1m"
  elif [ "$delta" -lt 3600 ]; then
    echo "$(( delta / 60 ))m"
  elif [ "$delta" -lt 86400 ]; then
    local h=$(( delta / 3600 ))
    local m=$(( (delta % 3600) / 60 ))
    if [ "$m" -gt 0 ]; then echo "${h}h ${m}m"; else echo "${h}h"; fi
  else
    echo "$(( delta / 86400 ))d"
  fi
}

# ---- Helper: format a reset epoch ----
# Args: $1 = epoch (may be empty/null/0), $2 = now epoch
# Echoes one of: "unknown" | "reset" | "<clock> · in <rel>"
fmt_reset() {
  local epoch=$1 now=$2
  if [ -z "$epoch" ] || [ "$epoch" = "null" ] || [ "$epoch" = "0" ]; then
    echo "unknown"; return
  fi
  local delta=$(( epoch - now ))
  if [ "$delta" -le 0 ]; then echo "reset"; return; fi
  local clock today reset_day
  today=$(date "+%Y-%m-%d")
  reset_day=$(date -r "$epoch" "+%Y-%m-%d" 2>/dev/null)
  if [ "$reset_day" = "$today" ]; then
    clock=$(date -r "$epoch" "+%-I:%M %p" 2>/dev/null)
  else
    clock=$(date -r "$epoch" "+%a %b %-d, %-I:%M %p" 2>/dev/null)
  fi
  echo "${clock} · in $(rel_time "$delta")"
}

# ---- Handle missing file ----
if [ ! -f "$STATUS_FILE" ]; then
  echo "CC: --"
  echo "---"
  echo "No data yet | color=#888888"
  echo "Start Claude Code to begin tracking | color=#888888"
  exit 0
fi

# ---- Read JSON ----
five_pct=$(jq -r '.five_hour_pct // 0' "$STATUS_FILE")
week_pct=$(jq -r '.seven_day_pct // 0' "$STATUS_FILE")
ctx_pct=$(jq -r '.context_pct // 0' "$STATUS_FILE")
model=$(jq -r '.model // "unknown"' "$STATUS_FILE")
updated_at=$(jq -r '.updated_at // ""' "$STATUS_FILE")
five_reset_epoch=$(jq -r '.five_hour_resets_at // empty' "$STATUS_FILE")
week_reset_epoch=$(jq -r '.seven_day_resets_at // empty' "$STATUS_FILE")

now_epoch=$(date -u +%s)

# ---- Calculate staleness ----
stale_label=""
if [ -n "$updated_at" ]; then
  updated_epoch=$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$updated_at" +%s 2>/dev/null || echo 0)
  age_seconds=$(( now_epoch - updated_epoch ))
  age_minutes=$(( age_seconds / 60 ))

  if [ "$age_minutes" -gt 15 ]; then
    stale_label=" (stale: ${age_minutes}m ago)"
  fi
fi

# ---- Reset display strings ----
five_reset_str=$(fmt_reset "$five_reset_epoch" "$now_epoch")
week_reset_str=$(fmt_reset "$week_reset_epoch" "$now_epoch")

# ---- Determine menu bar display ----
max_pct=$five_pct
if (( $(echo "$week_pct > $five_pct" | bc -l) )); then
  max_pct=$week_pct
fi

bar_color=$(color_for_pct "$max_pct")
five_color=$(color_for_pct "$five_pct")
week_color=$(color_for_pct "$week_pct")
ctx_color=$(color_for_pct "$ctx_pct")

# ---- Menu bar title (always visible) ----
if [ -n "$stale_label" ]; then
  printf "CC %.0f%%/%.0f%% [STALE] | color=#888888 sfSymbol=exclamationmark.triangle.fill\n" \
    "$five_pct" "$week_pct"
else
  # Append the 5h reset countdown only when the 5h budget is meaningfully used
  # (>40%) and we actually have a real future reset timestamp.
  title_suffix=""
  if (( $(echo "$five_pct > 40" | bc -l) )) \
     && [ -n "$five_reset_epoch" ] && [ "$five_reset_epoch" != "null" ] \
     && [ "$now_epoch" -lt "$five_reset_epoch" ]; then
    title_suffix=" · $(rel_time $(( five_reset_epoch - now_epoch )))"
  fi
  printf "CC %.0f%%/%.0f%%%s | color=%s sfSymbol=gauge.with.dots.needle.33percent\n" \
    "$five_pct" "$week_pct" "$title_suffix" "$bar_color"
fi

# ---- Dropdown menu ----
echo "---"
printf "5-Hour Usage:  %.1f%% | color=%s sfSymbol=clock\n" "$five_pct" "$five_color"
case "$five_reset_str" in
  unknown) echo "  ↳ Reset time unavailable | color=#888888 sfSymbol=questionmark.circle" ;;
  reset)   echo "  ↳ Window has reset since last update | color=#eab308 sfSymbol=arrow.clockwise.circle" ;;
  *)       printf "  ↳ Resets %s | color=#888888 sfSymbol=arrow.clockwise\n" "$five_reset_str" ;;
esac
printf "7-Day Usage:   %.1f%% | color=%s sfSymbol=calendar\n" "$week_pct" "$week_color"
case "$week_reset_str" in
  unknown) echo "  ↳ Reset time unavailable | color=#888888 sfSymbol=questionmark.circle" ;;
  reset)   echo "  ↳ Window has reset since last update | color=#eab308 sfSymbol=arrow.clockwise.circle" ;;
  *)       printf "  ↳ Resets %s | color=#888888 sfSymbol=arrow.clockwise\n" "$week_reset_str" ;;
esac
echo "---"
printf "Context Window: %.1f%% | color=%s sfSymbol=doc.text\n" "$ctx_pct" "$ctx_color"
printf "Model: %s | color=#888888 sfSymbol=cpu\n" "$model"
echo "---"

if [ -n "$stale_label" ]; then
  printf "Updated: %s%s | color=#ef4444 sfSymbol=exclamationmark.triangle\n" "$updated_at" "$stale_label"
else
  printf "Updated: %s | color=#888888 sfSymbol=checkmark.circle\n" "$updated_at"
fi

echo "---"
echo "Refresh | refresh=true"
