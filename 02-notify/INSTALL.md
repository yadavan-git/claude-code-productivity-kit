# Install — notify-me

**Prerequisite:** `jq` (macOS: `brew install jq`; Windows: `winget install jqlang.jq`).

## Quick install (recommended)

From this folder:

```bash
./install.sh
```

It copies the slash commands and the Stop hook, **merges** the hook entry into
`~/.claude/settings.json` (never replaces the file; timestamped backup first;
re-running won't register a duplicate), installs the macOS refocus variants or
the Windows toast helper automatically per platform, warns if another Stop
notifier is already registered, and ends by firing **one real test
notification** so you see it working. `./install.sh --uninstall` reverses it
(removing only this kit's hook entry — other hooks untouched).

Then **restart your Claude Code session** and arm it with `/notify-me test ping`.

## Manual install — everyone (macOS and Windows)

These steps are exactly what `install.sh` automates.

1. Copy the slash commands:

   ```bash
   mkdir -p ~/.claude/commands
   cp commands/notify-me.md commands/notify-me-ongoing.md commands/notify-cancel.md ~/.claude/commands/
   ```

2. Copy the Stop hook:

   ```bash
   mkdir -p ~/.claude/hooks
   cp scripts/notify-on-stop.sh ~/.claude/hooks/
   chmod +x ~/.claude/hooks/notify-on-stop.sh
   ```

3. Register it in `~/.claude/settings.json` (merge with any existing `hooks`
   key — and if a `Stop` entry already exists, check whether it's already a
   notifier before adding this one: two Stop notifiers means duplicate banners
   on every turn):

   ```json
   {
     "hooks": {
       "Stop": [
         {
           "hooks": [
             {
               "type": "command",
               "command": "bash \"$HOME/.claude/hooks/notify-on-stop.sh\""
             }
           ]
         }
       ]
     }
   }
   ```

4. **Restart your Claude Code session** (hooks and commands load at startup).

5. Verify: type `/notify-me test ping`, then send any short prompt. When the
   turn ends you should get a notification.

## Windows additionally

Copy the toast helper next to the hook:

```bash
cp scripts/show-toast.ps1 ~/.claude/hooks/
```

The Stop hook calls it via `powershell.exe` automatically when `osascript`
isn't present. It is **untested as of this writing** — if your first
`/notify-me test` produces no toast, run this directly in Git Bash and report
what happens:

```bash
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w ~/.claude/hooks/show-toast.ps1)" -Title "Claude Code" -Message "manual test"
```

Also check Windows Settings → System → Notifications: Focus Assist / Do Not
Disturb suppresses toasts, and PowerShell must be allowed to show them.

## macOS additionally (refocus variants)

```bash
cp commands/macos/*.md ~/.claude/commands/
cp scripts/macos/focus-claude-tab.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/focus-claude-tab.sh
```

Requires Terminal.app (the tab lookup is Terminal-specific — iTerm2 users:
the banner still works, refocus silently no-ops) and macOS Automation
permission the first time AppleScript touches Terminal.

Notification permissions: macOS asks once to allow notifications from Script
Editor/osascript; if you see nothing, check System Settings → Notifications.

## Uninstall

Remove the `Stop` hook block and the copied files; `/notify-cancel` any armed
sessions first (or just delete `~/.claude/session-env/`).
