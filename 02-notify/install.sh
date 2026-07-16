#!/usr/bin/env bash
# install.sh — one-command installer for the notify-me completion notifications.
#
#   ./install.sh              slash commands + Stop hook (macOS also gets the
#                             refocus variants; Windows Git Bash gets the toast helper)
#   ./install.sh --uninstall  reverse everything this script installed
#
# What it does: copies the slash commands to ~/.claude/commands/ and the Stop
# hook to ~/.claude/hooks/, MERGES the hook into settings.json (never replaces
# the file; timestamped backup first; idempotent — re-running won't register a
# second copy), then fires one real test notification so you see it working.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
CMDS_DIR="$CLAUDE_DIR/commands"
HOOKS_DIR="$CLAUDE_DIR/hooks"
SETTINGS="$CLAUDE_DIR/settings.json"
HOOK_CMD='bash "$HOME/.claude/hooks/notify-on-stop.sh"'

UNINSTALL=0
for arg in "$@"; do
  case "$arg" in
    --uninstall) UNINSTALL=1 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "Unknown option: $arg (try --help)" >&2; exit 2 ;;
  esac
done

die() { echo "✗ $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || die "jq is required. macOS: brew install jq — Windows: winget install jqlang.jq — then re-run."

os="$(uname -s 2>/dev/null || echo unknown)"
CORE_CMDS="notify-me.md notify-me-ongoing.md notify-cancel.md"
MAC_CMDS="notify-me-refocus.md notify-me-ongoing-refocus.md"

# ---------- uninstall ----------
if [ "$UNINSTALL" -eq 1 ]; then
  if [ -s "$SETTINGS" ] && jq -e . "$SETTINGS" >/dev/null 2>&1; then
    if jq -e --arg cmd "$HOOK_CMD" '[(.hooks.Stop // [])[] | .hooks[]?.command] | index($cmd)' "$SETTINGS" >/dev/null; then
      cp "$SETTINGS" "$SETTINGS.bak-$(date +%Y%m%d-%H%M%S)"
      tmp=$(mktemp) && jq --arg cmd "$HOOK_CMD" '
        .hooks.Stop = [(.hooks.Stop // [])[] | select(([.hooks[]?.command] | index($cmd)) | not)]
        | (if .hooks.Stop == [] then del(.hooks.Stop) else . end)
        | (if .hooks == {} then del(.hooks) else . end)' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
      echo "• removed the notify Stop hook from settings.json (backup kept; other hooks untouched)"
    fi
  fi
  for c in $CORE_CMDS $MAC_CMDS; do rm -f "$CMDS_DIR/$c"; done
  rm -f "$HOOKS_DIR/notify-on-stop.sh" "$HOOKS_DIR/focus-claude-tab.sh" "$HOOKS_DIR/show-toast.ps1"
  echo "• removed slash commands and scripts"
  [ -f "$CLAUDE_DIR/notify-events.jsonl" ] && echo "• kept ~/.claude/notify-events.jsonl (your notification history — delete it yourself if unwanted)"
  echo "• any armed sessions: flags live under ~/.claude/session-env/ and are inert without the hook"
  echo "✅ Uninstalled. Restart your Claude Code session to drop the commands."
  exit 0
fi

# ---------- install: copy commands + scripts ----------
mkdir -p "$CMDS_DIR" "$HOOKS_DIR"
copy_cmd() { # back up an existing, differing command file rather than silently clobbering
  if [ -f "$CMDS_DIR/$(basename "$1")" ] && ! cmp -s "$1" "$CMDS_DIR/$(basename "$1")"; then
    cp "$CMDS_DIR/$(basename "$1")" "$CMDS_DIR/$(basename "$1").bak-$(date +%Y%m%d-%H%M%S)"
    echo "  (your existing $(basename "$1") differed — backup kept next to it)"
  fi
  cp "$1" "$CMDS_DIR/"
}
for c in $CORE_CMDS; do copy_cmd "$HERE/commands/$c"; done
installed="core commands"
if [ "$os" = "Darwin" ]; then
  for c in $MAC_CMDS; do copy_cmd "$HERE/commands/macos/$c"; done
  cp "$HERE/scripts/macos/focus-claude-tab.sh" "$HOOKS_DIR/" && chmod +x "$HOOKS_DIR/focus-claude-tab.sh"
  installed="core + macOS refocus commands"
fi
case "$os" in MINGW*|MSYS*|CYGWIN*)
  cp "$HERE/scripts/show-toast.ps1" "$HOOKS_DIR/"
  installed="core commands + Windows toast helper" ;;
esac
cp "$HERE/scripts/notify-on-stop.sh" "$HOOKS_DIR/" && chmod +x "$HOOKS_DIR/notify-on-stop.sh"
echo "• installed $installed and the Stop hook script"

# ---------- install: merge the Stop hook into settings.json ----------
mkdir -p "$CLAUDE_DIR"
if [ -s "$SETTINGS" ]; then
  jq -e . "$SETTINGS" >/dev/null 2>&1 || die "~/.claude/settings.json exists but is not valid JSON. Fix it first — nothing was changed."
  if jq -e --arg cmd "$HOOK_CMD" '[(.hooks.Stop // [])[] | .hooks[]?.command] | index($cmd)' "$SETTINGS" >/dev/null; then
    echo "• Stop hook already registered — settings.json left as-is"
  else
    others=$(jq -r --arg cmd "$HOOK_CMD" '[(.hooks.Stop // [])[] | .hooks[]?.command | select(. != $cmd)] | join("\n")' "$SETTINGS")
    cp "$SETTINGS" "$SETTINGS.bak-$(date +%Y%m%d-%H%M%S)"
    tmp=$(mktemp) && jq --arg cmd "$HOOK_CMD" \
      '.hooks.Stop = ((.hooks.Stop // []) + [{hooks:[{type:"command", command:$cmd}]}])' \
      "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
    echo "• Stop hook merged into settings.json (backup kept; every other setting untouched)"
    if [ -n "$others" ]; then
      echo "  ⚠ you already had other Stop hook(s):"
      printf '      %s\n' $others
      echo "    If any of those is already a notifier, remove one — two notifiers = duplicate banners every turn."
    fi
  fi
else
  jq -n --arg cmd "$HOOK_CMD" '{hooks:{Stop:[{hooks:[{type:"command", command:$cmd}]}]}}' > "$SETTINGS"
  echo "• created settings.json with the Stop hook"
fi

# ---------- self-test: arm a fake session and fire the hook once ----------
sid="install-selftest-$$"
mkdir -p "$CLAUDE_DIR/session-env/$sid"
printf 'Install test — notifications are working' > "$CLAUDE_DIR/session-env/$sid/notify-when-done"
printf '{"session_id":"%s","cwd":"%s"}' "$sid" "$HOME" | bash "$HOOKS_DIR/notify-on-stop.sh"
if [ ! -f "$CLAUDE_DIR/session-env/$sid/notify-when-done" ] \
   && tail -1 "$CLAUDE_DIR/notify-events.jsonl" 2>/dev/null | grep -q "$sid"; then
  echo "• self-test: hook fired and logged — you should have just seen a notification"
else
  die "self-test failed — the hook did not fire/log correctly"
fi
rm -rf "$CLAUDE_DIR/session-env/$sid"

# ---------- done: how to use it ----------
cat <<'EOF'
✅ Installed. Restart your Claude Code session (commands and hooks load at startup), then:

   /notify-me tests done        one banner when the current turn finishes
   /notify-me-ongoing           a banner after every turn, until /notify-cancel
   /notify-cancel               disarm this session
   (macOS also) /notify-me-refocus, /notify-me-ongoing-refocus — same, plus they
   raise the right Terminal tab without stealing your focus.

   If the self-test showed NO banner just now: macOS → System Settings →
   Notifications → allow osascript/Script Editor; Windows → check Focus Assist.
EOF
