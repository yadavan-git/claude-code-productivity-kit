---
description: Ping me + raise (but don't steal focus from) my Terminal tab on every turn (until /notify-cancel)
allowed-tools: Bash
---

Arm a persistent completion notification. On every Stop:
  - banner fires
  - the Claude session's Terminal tab is raised within Terminal (window-order + tab selection)
  - but Terminal is NOT brought to the foreground

Persists until disarmed with /notify-cancel.

Run exactly this:

```bash
SID="${CLAUDE_CODE_SESSION_ID:?CLAUDE_CODE_SESSION_ID not set in env}"
mkdir -p "$HOME/.claude/session-env/$SID"
LABEL="$ARGUMENTS"
[ -z "$LABEL" ] && LABEL="Claude finished"
printf '%s' "$LABEL" > "$HOME/.claude/session-env/$SID/notify-ongoing-refocus"
```

Then reply with one short line: `Ongoing (refocus) — pinging + raising tab (no focus steal) every turn until /notify-cancel.`
