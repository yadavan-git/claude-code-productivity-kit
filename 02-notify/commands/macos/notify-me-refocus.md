---
description: Ping me + raise (but don't steal focus from) my Terminal tab when this turn finishes (one-shot)
allowed-tools: Bash
---

Arm a one-shot completion notification. When the turn ends:
  - banner fires
  - the Claude session's Terminal tab is raised within Terminal (window-order + tab selection)
  - but Terminal is NOT brought to the foreground — whatever app you're using stays focused

Effect: next time you switch to Terminal, the right window/tab is already on top.

Run exactly this:

```bash
SID="${CLAUDE_CODE_SESSION_ID:?CLAUDE_CODE_SESSION_ID not set in env}"
mkdir -p "$HOME/.claude/session-env/$SID"
LABEL="$ARGUMENTS"
[ -z "$LABEL" ] && LABEL="Claude finished"
printf '%s' "$LABEL" > "$HOME/.claude/session-env/$SID/notify-when-done-refocus"
```

Then reply with one short line: `Armed (refocus) — will ping + raise this tab (no focus steal) when done.`
