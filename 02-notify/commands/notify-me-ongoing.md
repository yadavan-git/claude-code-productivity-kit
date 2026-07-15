---
description: Ping me with a desktop notification at the end of every turn (until /notify-cancel)
allowed-tools: Bash
---

Arm a persistent completion notification for the current session. Notifications will fire on every Stop until disarmed with /notify-cancel.

Run exactly this:

```bash
SID="${CLAUDE_CODE_SESSION_ID:?CLAUDE_CODE_SESSION_ID not set in env}"
mkdir -p "$HOME/.claude/session-env/$SID"
LABEL="$ARGUMENTS"
[ -z "$LABEL" ] && LABEL="Claude finished"
printf '%s' "$LABEL" > "$HOME/.claude/session-env/$SID/notify-ongoing"
```

Then reply with one short line: `Ongoing — pinging every turn until /notify-cancel.`
