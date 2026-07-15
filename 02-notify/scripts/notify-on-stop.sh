#!/usr/bin/env bash
# Stop hook: fire a desktop notification if /notify-me (any variant) has armed
# this session.
#
# stdin: hook JSON payload with .session_id
# Notifier, by platform:
#   - macOS:                osascript banner (with sound)
#   - Windows (Git Bash):   PowerShell toast via show-toast.ps1
#   - anything else:        terminal bell
# Exits 0 on every path so it never blocks Claude Code.

set +e

payload=$(cat)
sid=$(printf '%s' "$payload" | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$sid" ] && exit 0

DIR="$HOME/.claude/session-env/$sid"
once_flag="$DIR/notify-when-done"
once_refocus_flag="$DIR/notify-when-done-refocus"
ongoing_flag="$DIR/notify-ongoing"
ongoing_refocus_flag="$DIR/notify-ongoing-refocus"

# Resolve which flag fired. Priority: one-shot variants beat ongoing; within
# each group the most-recently-armed file wins, so re-arming with a different
# variant behaves intuitively.
pick_newest() {
  local newest=""
  for f in "$@"; do
    [ -f "$f" ] || continue
    if [ -z "$newest" ] || [ "$f" -nt "$newest" ]; then newest="$f"; fi
  done
  printf '%s' "$newest"
}

active_once=$(pick_newest "$once_flag" "$once_refocus_flag")
active_ongoing=$(pick_newest "$ongoing_flag" "$ongoing_refocus_flag")

if [ -n "$active_once" ]; then
  active_flag="$active_once"
  mode="once"
elif [ -n "$active_ongoing" ]; then
  active_flag="$active_ongoing"
  mode="ongoing"
else
  exit 0
fi

# Refocus variants (macOS-only extra; see macos/focus-claude-tab.sh)
refocus="no"
case "$active_flag" in
  *-refocus) refocus="yes" ;;
esac

tp=$(printf '%s' "$payload" | jq -r '.transcript_path // empty' 2>/dev/null)
cwd=$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null)

# Chat name for the notification subtitle: session name -> last AI title -> cwd basename
chat_name=""
for f in "$HOME"/.claude/sessions/*.json; do
  [ -f "$f" ] || continue
  match=$(jq -r --arg sid "$sid" 'select(.sessionId == $sid) | .name // empty' "$f" 2>/dev/null)
  if [ -n "$match" ]; then
    chat_name="$match"
    break
  fi
done
if [ -z "$chat_name" ] && [ -n "$tp" ] && [ -f "$tp" ]; then
  chat_name=$(jq -r 'select(.type=="ai-title") | .aiTitle // empty' "$tp" 2>/dev/null | tail -1)
fi
[ -z "$chat_name" ] && [ -n "$cwd" ] && chat_name=$(basename "$cwd")
[ -z "$chat_name" ] && chat_name="Claude session"
chat_name=$(printf '%s' "$chat_name" | tr '\n\r\t' '   ' | cut -c 1-80)

label=$(cat "$active_flag" 2>/dev/null)
[ -z "$label" ] && label="Claude finished"

# ---- Fire the notification, per platform ----
esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

if command -v osascript >/dev/null 2>&1; then
  osascript -e "display notification \"$(esc "$label")\" with title \"Claude Code\" subtitle \"$(esc "$chat_name")\" sound name \"Glass\"" >/dev/null 2>&1
elif command -v powershell.exe >/dev/null 2>&1; then
  toast_ps1="$HOME/.claude/hooks/show-toast.ps1"
  if [ -f "$toast_ps1" ]; then
    # Git Bash: convert to a Windows path for -File; strip double quotes from
    # the message so PowerShell's argument re-parsing can't break on them.
    win_path=$(cygpath -w "$toast_ps1" 2>/dev/null || printf '%s' "$toast_ps1")
    msg=$(printf '%s: %s' "$chat_name" "$label" | tr -d '"')
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$win_path" -Title "Claude Code" -Message "$msg" >/dev/null 2>&1
  fi
else
  printf '\a' > /dev/tty 2>/dev/null
fi

# ---- Refocus (macOS-only): raise this session's Terminal tab without stealing focus ----
tty_path=""
if [ "$refocus" = "yes" ] && command -v osascript >/dev/null 2>&1; then
  session_pid=""
  for f in "$HOME"/.claude/sessions/*.json; do
    [ -f "$f" ] || continue
    p=$(jq -r --arg sid "$sid" 'select(.sessionId == $sid) | .pid // empty' "$f" 2>/dev/null)
    if [ -n "$p" ]; then session_pid="$p"; break; fi
  done
  if [ -n "$session_pid" ]; then
    t=$(ps -o tty= -p "$session_pid" 2>/dev/null | tr -d ' ')
    [ -n "$t" ] && [ "$t" != "??" ] && tty_path="/dev/$t"
  fi
  if [ -n "$tty_path" ] && [ -x "$HOME/.claude/hooks/focus-claude-tab.sh" ]; then
    "$HOME/.claude/hooks/focus-claude-tab.sh" --no-activate "$tty_path" >/dev/null 2>&1
  fi
fi

# ---- Event log ----
log="$HOME/.claude/notify-events.jsonl"
ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
label_json=$(printf '%s' "$label" | jq -Rs .)
chat_json=$(printf '%s' "$chat_name" | jq -Rs .)
printf '{"ts":"%s","session_id":"%s","chat":%s,"label":%s,"mode":"%s","refocus":"%s","tty":"%s"}\n' \
  "$ts" "$sid" "$chat_json" "$label_json" "$mode" "$refocus" "$tty_path" >> "$log"

# Consume one-shot flag; leave ongoing flags in place
[ "$mode" = "once" ] && rm -f "$active_flag"
exit 0
