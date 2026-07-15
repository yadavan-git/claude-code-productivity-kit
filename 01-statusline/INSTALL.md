# Install — statusline

**Prerequisite:** `jq` (macOS: `brew install jq`; Windows: `winget install jqlang.jq`).

## Basic statusline (macOS, Linux, Windows)

1. Copy the script:

   ```bash
   mkdir -p ~/.claude/hooks
   cp statusline.sh ~/.claude/hooks/
   chmod +x ~/.claude/hooks/statusline.sh
   ```

2. Add to `~/.claude/settings.json`:

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

## Full tracker + menu-bar widget (macOS only)

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

- The rate-limit numbers are only as fresh as the current session's last
  API exchange; right after starting a session they can lag a few minutes.
  The full script guards against a laggy reading overwriting a good one.
- The full tracker also appends once-per-minute history to
  `~/.claude/usage-history.jsonl` — handy raw material if you ever want to
  chart your own usage patterns.
