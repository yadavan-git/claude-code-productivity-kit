# 2 · Attention — "Tell me when it's done."

## The pain

Claude Code turns run long — a good research or refactoring turn can take
several minutes. So you tab away. And then Claude finished eight minutes ago
(or worse: it's been sitting *blocked on a question for you*), and the elapsed
time between "done" and "you noticed" is pure waste. Multiply by every turn of
every session and it's the single biggest tax on working with an agent.

## Primer: the two mechanisms

**Custom slash commands.** A markdown file dropped in `~/.claude/commands/`
becomes a `/command` in every session. The file's body is an instruction to
Claude ("run exactly this…"), so a command can do real work — here, writing a
small flag file.

**The Stop hook.** A script registered under `hooks.Stop` in `settings.json`
runs every time Claude ends a turn, receiving session metadata (session id,
transcript path, cwd) as JSON on stdin.

Put together: the slash command *arms* a per-session flag file; the Stop hook
checks for it and fires a notification. The flag lives in a directory keyed by
session id, so each session is armed independently.

## The commands (four iterations + cancel)

| Command | What it does | Platforms |
|---|---|---|
| `/notify-me [label]` | One notification when the current turn finishes, then disarms | macOS, Windows |
| `/notify-me-ongoing [label]` | Notification at the end of **every** turn until cancelled | macOS, Windows |
| `/notify-me-refocus [label]` | One-shot, **plus** raises this session's Terminal tab — without stealing focus from the app you're in. Next time you switch to Terminal, the right tab is already on top | macOS only |
| `/notify-me-ongoing-refocus [label]` | The ongoing version of refocus | macOS only |
| `/notify-cancel` | Disarms everything for this session | all |

The optional `[label]` becomes the notification text — arm different sessions
with different labels ("tests done", "migration finished") and you can tell
them apart from the banner alone.

These evolved in exactly this order, and the progression is the useful lesson:
one-shot → ongoing (because re-arming every turn got old) → refocus variants
(because the banner tells you *that* it's done, but you still had to hunt for
*which* terminal tab among many). Adopt as far up the chain as your workflow
needs; the notification (macOS banner / Windows toast) fires per platform,
while refocus is AppleScript-based and stays macOS-only.

Also try first: Claude Code has a built-in `preferredNotifChannel` setting
(e.g. terminal bell). This kit exists because a bell doesn't help when you're
in another app — and per-session arming with labels doesn't exist natively.

## How it works, in one breath

`/notify-me-ongoing "tests"` → Claude writes `tests` into
`~/.claude/session-env/<session-id>/notify-ongoing` → every Stop, the hook
finds the flag, resolves the conversation title (manual rename → AI-generated
title → session name → directory name), fires the platform notifier, and
appends an event to a local log. One-shot flags are consumed; ongoing flags persist until
`/notify-cancel`.

## Windows?

Yes, for the two core commands: the Stop hook runs under Git Bash and
dispatches to a bundled PowerShell toast script (`scripts/show-toast.ps1`,
no modules required — deliberately avoids BurntToast, whose install is often
blocked on managed devices). **The toast script is untested until the first
Windows user confirms it** — a documented fallback to a tray balloon is built
in. Refocus variants: macOS only, no port planned.

## Files

| File | Purpose |
|---|---|
| `commands/notify-me.md`, `commands/notify-me-ongoing.md`, `commands/notify-cancel.md` | The portable slash commands |
| `commands/macos/notify-me-refocus.md`, `commands/macos/notify-me-ongoing-refocus.md` | The refocus variants (macOS) |
| `scripts/notify-on-stop.sh` | The Stop hook (cross-platform dispatcher) |
| `scripts/show-toast.ps1` | Windows toast helper |
| `scripts/macos/focus-claude-tab.sh` | Terminal-tab refocus helper (macOS) |
| `INSTALL.md` | Step-by-step install |
