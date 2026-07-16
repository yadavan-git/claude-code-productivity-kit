# Install — statusline

**Prerequisite:** `jq` (macOS: `brew install jq`; Windows: `winget install jqlang.jq`).

## Quick install (recommended)

From this folder:

```bash
./install.sh          # basic statusline — macOS, Linux, Windows (Git Bash)
./install.sh --full   # macOS: also the full tracker + SwiftBar menu-bar widget
```

The script copies the statusline into `~/.claude/hooks/`, **merges** the
`statusLine` entry into `~/.claude/settings.json` (it never replaces the file,
and takes a timestamped backup first), auto-detects your SwiftBar plugin
folder, and finishes with a self-test that prints the rendered bar so you can
see it working before you restart. Safe to re-run; `./install.sh --uninstall`
reverses it. If a *different* statusLine is already configured it stops and
tells you instead of overwriting (`--force` to replace).

Then **restart your Claude Code session** — the bar appears after the first turn.

## Manual install — basic statusline (macOS, Linux, Windows)

These steps are exactly what `install.sh` automates.

1. Copy the script:

   ```bash
   mkdir -p ~/.claude/hooks
   cp statusline.sh ~/.claude/hooks/
   chmod +x ~/.claude/hooks/statusline.sh
   ```

2. Add the `statusLine` key to `~/.claude/settings.json`.

   ⚠️ **Merge this key into your existing file — do not paste the block below
   as the whole file**, or you'll wipe every other setting you have (model,
   permissions, hooks, …). The safe one-liner:

   ```bash
   tmp=$(mktemp) && jq '.statusLine = {type:"command", command:"bash \"$HOME/.claude/hooks/statusline.sh\""}' \
     ~/.claude/settings.json > "$tmp" && mv "$tmp" ~/.claude/settings.json
   ```

   Which results in this key being present:

   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "bash \"$HOME/.claude/hooks/statusline.sh\""
     }
   }
   ```

   Windows: keep the forward slashes exactly as above — Git Bash treats
   backslashes as escape characters.

3. Restart your Claude Code session. The bar appears after the first turn.

## Manual install — full tracker + menu-bar widget (macOS only)

1. Install [SwiftBar](https://swiftbar.app) (`brew install swiftbar`) and pick
   a plugin folder when it first launches.

2. Use the full statusline instead of the basic one:

   ```bash
   cp macos/statusline-full.sh ~/.claude/hooks/
   chmod +x ~/.claude/hooks/statusline-full.sh
   ```

   …and point the `statusLine` command at `statusline-full.sh` instead.

3. Drop the widget into your SwiftBar plugin folder:

   ```bash
   cp macos/claude-usage.30s.sh "<your SwiftBar plugin folder>/"
   chmod +x "<your SwiftBar plugin folder>/claude-usage.30s.sh"
   ```

   The `30s` in the filename is the refresh interval — SwiftBar convention.

4. Restart your Claude Code session, run one turn, and `CC n%/n%` appears in
   the menu bar. It reads `~/.claude/usage-status.json`, which the full
   statusline writes; if the menu bar shows `[STALE]`, no Claude Code session
   has reported recently — that's the widget working as designed.

## Notes

- The 5h/7d numbers come from **Claude.ai Pro/Max subscription rate limits**
  and appear after the session's first response. On API-key billing the
  payload has no `rate_limits` at all, so the bar shows `ctx` only — expected
  behavior, not a bug.
- The rate-limit numbers are only as fresh as the current session's last
  API exchange; right after starting a session they can lag a few minutes.
  The full script guards against a laggy reading overwriting a good one.
- The full tracker also appends once-per-minute history to
  `~/.claude/usage-history.jsonl` — handy raw material if you ever want to
  chart your own usage patterns.
