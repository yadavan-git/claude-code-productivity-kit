#!/usr/bin/env bash
# Activate Terminal.app and focus a specific tab.
#
# Usage:
#   focus-claude-tab.sh /dev/ttys000        # focus the tab with that TTY
#   focus-claude-tab.sh --session <uuid>    # focus the tab for that Claude session
#   focus-claude-tab.sh --last              # focus the tab of the most recent /notify-me fire
#   focus-claude-tab.sh                     # just activate Terminal (no specific tab)

set +e

resolve_tty_from_session() {
    local sid="$1"
    local pid=""
    for f in "$HOME"/.claude/sessions/*.json; do
        [ -f "$f" ] || continue
        local p
        p=$(jq -r --arg sid "$sid" 'select(.sessionId == $sid) | .pid // empty' "$f" 2>/dev/null)
        if [ -n "$p" ]; then pid="$p"; break; fi
    done
    [ -z "$pid" ] && return 1
    local t
    t=$(ps -o tty= -p "$pid" 2>/dev/null | tr -d ' ')
    [ -z "$t" ] || [ "$t" = "??" ] && return 1
    echo "/dev/$t"
}

resolve_tty_from_last_notify() {
    local log="$HOME/.claude/notify-events.jsonl"
    [ -f "$log" ] || return 1
    # find the most recent posted event with a session_id, then resolve its TTY now
    local sid
    sid=$(tail -r "$log" 2>/dev/null | jq -r 'select(.session_id and .session_id != "") | .session_id' 2>/dev/null | head -1)
    [ -z "$sid" ] && return 1
    resolve_tty_from_session "$sid"
}

NO_ACTIVATE=0
if [ "${1:-}" = "--no-activate" ]; then
    NO_ACTIVATE=1
    shift
fi

TTY=""
case "${1:-}" in
    --session)
        TTY=$(resolve_tty_from_session "${2:-}") || true
        ;;
    --last)
        TTY=$(resolve_tty_from_last_notify) || true
        ;;
    "")
        TTY=""
        ;;
    *)
        TTY="$1"
        ;;
esac

if [ -z "$TTY" ]; then
    if [ "$NO_ACTIVATE" -eq 0 ]; then
        osascript -e 'tell application "Terminal" to activate' >/dev/null 2>&1
    fi
    exit 0
fi

ACTIVATE_LINE="activate"
[ "$NO_ACTIVATE" -eq 1 ] && ACTIVATE_LINE=""

osascript 2>/dev/null <<EOF
tell application "Terminal"
  $ACTIVATE_LINE
  set targetTTY to "$TTY"
  repeat with w in windows
    repeat with i from 1 to (count of tabs of w)
      if tty of tab i of w is targetTTY then
        set selected tab of w to tab i of w
        set index of w to 1
        return
      end if
    end repeat
  end repeat
end tell
EOF
exit 0
