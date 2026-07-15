# Install — auto-approval ladder

**Prerequisite for Tiers 1–2:** `jq`.
macOS: `brew install jq` (or grab the binary from jqlang.github.io/jq).
Windows: `winget install jqlang.jq`.
Check: `jq --version`.

**Applies to every tier below:** settings changes and hooks load at session
start — **restart your Claude Code session** after installing.

## Tier 0 — allowlist

Option A (interactive): run `/permissions` inside Claude Code and add rules
from [`allowlist-starter.json`](allowlist-starter.json) at your preferred scope.

Option B (edit the file): merge the `permissions.allow` array into
`~/.claude/settings.json`. If the file already has a `permissions.allow` array,
append entries — don't add a second key.

Scopes, for later tuning: `~/.claude/settings.json` = you, everywhere.
`<repo>/.claude/settings.json` = whole team, that repo (committed to git).
`<repo>/.claude/settings.local.json` = you, that repo.

## Tier 1 — logging hook

1. Copy the hook where Claude Code can find it:

   ```bash
   mkdir -p ~/.claude/hooks
   cp hooks/log-permission-requests.sh ~/.claude/hooks/
   chmod +x ~/.claude/hooks/log-permission-requests.sh
   ```

2. Register it in `~/.claude/settings.json` (merge with any existing `hooks` key):

   ```json
   {
     "hooks": {
       "PermissionRequest": [
         {
           "hooks": [
             {
               "type": "command",
               "command": "bash \"$HOME/.claude/hooks/log-permission-requests.sh\"",
               "timeout": 10
             }
           ]
         }
       ]
     }
   }
   ```

3. Restart your session. Verify after a few prompts:
   `tail ~/.claude/permission-requests.jsonl`

## Tier 2 — auto-approve hook

Read [../SECURITY.md](../SECURITY.md) first.

1. Copy the hook:

   ```bash
   mkdir -p ~/.claude/hooks
   cp hooks/auto-approve.sh ~/.claude/hooks/
   chmod +x ~/.claude/hooks/auto-approve.sh
   ```

2. Register it — and if you installed Tier 1, **replace** that hook entry
   rather than stacking both (Tier 2 logs everything Tier 1 would):

```json
{
  "hooks": {
    "PermissionRequest": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$HOME/.claude/hooks/auto-approve.sh\"",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

To scope it to one trusted repo instead of everything: put that same block in
`<repo>/.claude/settings.json` (or `.local.json`) instead of `~/.claude/settings.json`.

If you also run section 3's remote approver, use this hook block instead —
same shape, with the approver wired in via `CLAUDE_REMOTE_APPROVER` and a
timeout long enough for the phone round-trip:

```json
{
  "hooks": {
    "PermissionRequest": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "CLAUDE_REMOTE_APPROVER=\"/absolute/path/to/node /absolute/path/to/claude-remote-approver/bin/cli.mjs hook\" bash \"$HOME/.claude/hooks/auto-approve.sh\"",
            "timeout": 90
          }
        ]
      }
    ]
  }
}
```

(Absolute paths matter: hooks run outside your interactive shell's PATH.
Find them with `which node` and `npm root -g`.)

Verify both directions after restarting:

- Ask Claude to run something harmless that would normally prompt — e.g.
  `touch /tmp/kit-test` — it should sail through with no prompt, and
  `tail -1 ~/.claude/permission-requests.jsonl` shows `auto_allow`.
  (Don't test with `ls`/`grep`: Claude Code auto-approves simple read-only
  commands natively, so they never reach the hook or the log.)
- Ask Claude to `git push` in a scratch repo — the prompt (or your phone
  push) appears, and the log shows `human_prompt` (or `human_remote`).

## Windows notes

- Claude Code requires Git for Windows; hook commands run through **Git Bash**
  when it's installed (PowerShell otherwise), so the `bash "$HOME/…"` commands
  above should work unchanged. This shell-selection rule is documented for
  statusline commands and believed to apply to hooks — **the first Windows
  installer should confirm and report back.**
- Write paths in `command` strings with **forward slashes** — Git Bash eats
  unquoted backslashes.
- `~/.claude/` = `C:\Users\<you>\.claude\` (i.e. `%USERPROFILE%\.claude\`).

## Uninstall

Remove the hook block from settings.json and restart the session. The log file
is yours to keep or delete: `~/.claude/permission-requests.jsonl`.
