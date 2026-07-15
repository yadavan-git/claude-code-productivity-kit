---
description: Ping me with a desktop notification when this turn finishes (one-shot)
allowed-tools: Bash
---

Arm a one-shot completion notification for the current session.

Run exactly this:

```bash
SID="${CLAUDE_CODE_SESSION_ID:?CLAUDE_CODE_SESSION_ID not set in env}"
mkdir -p "$HOME/.claude/session-env/$SID"
LABEL="$ARGUMENTS"
[ -z "$LABEL" ] && LABEL="Claude finished"
printf '%s' "$LABEL" > "$HOME/.claude/session-env/$SID/notify-when-done"
```

Then reply with one short line: `Armed — will ping when this finishes.`
