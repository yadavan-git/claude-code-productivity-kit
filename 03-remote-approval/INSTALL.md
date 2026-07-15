# Install — remote approval

**Prerequisites:** Node ≥18 (macOS: `brew install node`; Windows:
`winget install OpenJS.NodeJS.LTS`), and the **ntfy** app on your phone
(App Store / Play Store, free, no account needed).

## Standalone install

```bash
npm install -g claude-remote-approver
claude-remote-approver setup
```

Setup generates your private topic, registers the PermissionRequest hook in
`~/.claude/settings.json`, and prints a QR code — scan it with the ntfy app to
subscribe. Then **start a new Claude Code session** (the hook loads at
startup).

Verify: `claude-remote-approver test` sends a test push. Then ask Claude to do
something that needs permission and approve it from your phone.

Day-to-day management:

```bash
claude-remote-approver status     # config + connectivity
claude-remote-approver disable    # pause (topic preserved)
claude-remote-approver enable
claude-remote-approver uninstall  # removes hook + config
```

Gotchas:

- Hooks run outside your login shell's PATH. If the hook doesn't fire, edit
  the hook entry in `~/.claude/settings.json` to use absolute paths to both
  `node` and the tool's `cli.mjs`.
- On timeout (~20–30s unanswered) the terminal prompt appears — that's the
  designed fallback, not a bug.
- Corporate networks/proxies may block ntfy.sh — `claude-remote-approver test`
  is the quick diagnostic.

## Self-hosted server (required posture for client data)

Edit `~/.claude-remote-approver.json`:

```json
{
  "ntfyServer": "https://ntfy.your-org.example"
}
```

Basic Auth for authenticated topics is supported via `ntfyUsername` /
`ntfyPassword` in the same file (or `NTFY_USERNAME` / `NTFY_PASSWORD` env
vars, which take priority). Re-subscribe your phone against the new server.
See the [upstream README](https://github.com/yuuichieguchi/claude-remote-approver)
for full config reference.

## Combo with section 4 (Tier 2)

Once standalone mode works, switch to: Tier 2 auto-approves locally,
needs-human cases go to your phone.

1. In `~/.claude/settings.json`, **replace** the hook entry the approver's
   setup registered with the Tier 2 entry from
   [../04-auto-approval/INSTALL.md](../04-auto-approval/INSTALL.md), using the
   `CLAUDE_REMOTE_APPROVER` variant — the wrapper invokes the approver's
   `cli.mjs hook` only for its needs-human cases.
2. Keep `timeout` at ~90 (seconds) so the phone round-trip fits.
3. Restart the session. Verify both paths: a read-only command sails through
   silently; a `git push` buzzes your phone.

## Uninstall

`claude-remote-approver uninstall` (or if running the combo: remove the
`CLAUDE_REMOTE_APPROVER` variable from the Tier 2 hook entry).
