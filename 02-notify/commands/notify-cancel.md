---
description: Cancel a pending /notify-me for this session
allowed-tools: Bash
---

Disarm the pending completion notification.

Run:

```bash
SID="${CLAUDE_CODE_SESSION_ID:?CLAUDE_CODE_SESSION_ID not set in env}"
rm -f "$HOME/.claude/session-env/$SID/notify-when-done" \
       "$HOME/.claude/session-env/$SID/notify-ongoing" \
       "$HOME/.claude/session-env/$SID/notify-when-done-refocus" \
       "$HOME/.claude/session-env/$SID/notify-ongoing-refocus"
```

Reply with one short line: `Disarmed.`
