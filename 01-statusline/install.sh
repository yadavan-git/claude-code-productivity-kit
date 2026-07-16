#!/usr/bin/env bash
# install.sh — one-command installer for the Claude Code statusline.
#
#   ./install.sh              basic statusline (macOS / Linux / Windows Git Bash)
#   ./install.sh --full       macOS: full tracker (persists usage for the menu-bar
#                             widget) + SwiftBar widget, if SwiftBar is set up
#   ./install.sh --force      proceed even if a DIFFERENT statusLine is already
#                             configured (a timestamped backup is always taken)
#   ./install.sh --uninstall  reverse everything this script installed
#
# What it does: copies the script(s) to ~/.claude/hooks/, MERGES the statusLine
# key into ~/.claude/settings.json (never replaces the file; backs it up first),
# runs a self-test with mock session JSON, and prints what's left to do.
# Safe to re-run. Env override: SWIFTBAR_PLUGIN_DIR=<dir> skips autodetection.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks"
SETTINGS="$CLAUDE_DIR/settings.json"
BASIC_CMD='bash "$HOME/.claude/hooks/statusline.sh"'
FULL_CMD='bash "$HOME/.claude/hooks/statusline-full.sh"'

FULL=0; FORCE=0; UNINSTALL=0
for arg in "$@"; do
  case "$arg" in
    --full) FULL=1 ;;
    --force) FORCE=1 ;;
    --uninstall) UNINSTALL=1 ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "Unknown option: $arg (try --help)" >&2; exit 2 ;;
  esac
done

die() { echo "✗ $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || die "jq is required. macOS: brew install jq — Windows: winget install jqlang.jq — then re-run."

os="$(uname -s 2>/dev/null || echo unknown)"
[ "$FULL" -eq 1 ] && [ "$os" != "Darwin" ] && die "--full is macOS-only (BSD date + SwiftBar). Run without --full for the portable statusline."

# Where's the SwiftBar plugin folder? Env override first, then SwiftBar's own preference.
swiftbar_dir() {
  if [ -n "${SWIFTBAR_PLUGIN_DIR:-}" ]; then echo "$SWIFTBAR_PLUGIN_DIR"; return; fi
  defaults read com.ameba.SwiftBar PluginDirectory 2>/dev/null || true
}

# ---------- uninstall ----------
if [ "$UNINSTALL" -eq 1 ]; then
  if [ -s "$SETTINGS" ] && jq -e . "$SETTINGS" >/dev/null 2>&1; then
    current=$(jq -r '.statusLine.command // empty' "$SETTINGS")
    if [ "$current" = "$BASIC_CMD" ] || [ "$current" = "$FULL_CMD" ]; then
      cp "$SETTINGS" "$SETTINGS.bak-$(date +%Y%m%d-%H%M%S)"
      tmp=$(mktemp) && jq 'del(.statusLine)' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
      echo "• removed statusLine from settings.json (backup kept alongside it)"
    elif [ -n "$current" ]; then
      echo "• settings.json statusLine points elsewhere ($current) — left untouched"
    fi
  fi
  rm -f "$HOOKS_DIR/statusline.sh" "$HOOKS_DIR/statusline-full.sh" && echo "• removed scripts from ~/.claude/hooks/"
  sb="$(swiftbar_dir)"
  [ -n "$sb" ] && [ -f "$sb/claude-usage.30s.sh" ] && rm -f "$sb/claude-usage.30s.sh" && echo "• removed SwiftBar widget"
  rm -f "$CLAUDE_DIR/usage-status.json"
  [ -f "$CLAUDE_DIR/usage-history.jsonl" ] && echo "• kept ~/.claude/usage-history.jsonl (your usage history — delete it yourself if unwanted)"
  echo "✅ Uninstalled. Restart your Claude Code session to drop the bar."
  exit 0
fi

# ---------- install: copy scripts ----------
mkdir -p "$HOOKS_DIR"
cp "$HERE/statusline.sh" "$HOOKS_DIR/" && chmod +x "$HOOKS_DIR/statusline.sh"
target_cmd="$BASIC_CMD"; target_script="$HOOKS_DIR/statusline.sh"
if [ "$FULL" -eq 1 ]; then
  cp "$HERE/macos/statusline-full.sh" "$HOOKS_DIR/" && chmod +x "$HOOKS_DIR/statusline-full.sh"
  target_cmd="$FULL_CMD"; target_script="$HOOKS_DIR/statusline-full.sh"
fi
echo "• scripts copied to ~/.claude/hooks/"

# ---------- install: merge settings.json ----------
mkdir -p "$CLAUDE_DIR"
if [ -s "$SETTINGS" ]; then
  jq -e . "$SETTINGS" >/dev/null 2>&1 || die "~/.claude/settings.json exists but is not valid JSON. Fix it first — nothing was changed."
  existing=$(jq -r '.statusLine.command // empty' "$SETTINGS")
  if [ -n "$existing" ] && [ "$existing" != "$target_cmd" ] && [ "$FORCE" -eq 0 ]; then
    if [ -t 0 ]; then
      printf 'A different statusLine is already configured:\n  %s\nReplace it? [y/N] ' "$existing"
      read -r ans; case "$ans" in y|Y) : ;; *) die "kept your existing statusLine. Re-run with --force to replace it." ;; esac
    else
      die "a different statusLine is already configured: $existing — re-run with --force to replace it (a backup will be kept)."
    fi
  fi
  cp "$SETTINGS" "$SETTINGS.bak-$(date +%Y%m%d-%H%M%S)"
  tmp=$(mktemp) && jq --arg cmd "$target_cmd" '.statusLine = {type:"command", command:$cmd}' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
  echo "• statusLine merged into settings.json (backup kept; every other setting untouched)"
else
  jq -n --arg cmd "$target_cmd" '{statusLine:{type:"command", command:$cmd}}' > "$SETTINGS"
  echo "• created settings.json with the statusLine entry"
fi

# ---------- install: SwiftBar widget (--full only) ----------
if [ "$FULL" -eq 1 ]; then
  sb="$(swiftbar_dir)"
  if [ -n "$sb" ] && [ -d "$sb" ]; then
    cp "$HERE/macos/claude-usage.30s.sh" "$sb/" && chmod +x "$sb/claude-usage.30s.sh"
    echo "• SwiftBar widget installed to $sb"
  else
    echo "• SwiftBar not detected — for the menu-bar widget: install SwiftBar (https://swiftbar.app),"
    echo "  pick a plugin folder on first launch, then re-run ./install.sh --full"
  fi
fi

# ---------- self-test with mock session JSON ----------
now=$(date +%s)
mock=$(jq -n --arg cwd "$HOME" --argjson t "$now" \
  '{workspace:{current_dir:$cwd}, model:{display_name:"Opus 4.8"},
    context_window:{used_percentage:12.5},
    rate_limits:{five_hour:{used_percentage:27, resets_at:($t+7200)},
                 seven_day:{used_percentage:8, resets_at:($t+200000)}}}')
if [ "$FULL" -eq 1 ]; then
  # run against a throwaway HOME so mock data never touches the real usage-status.json
  fake=$(mktemp -d); mkdir -p "$fake/.claude"
  out=$(printf '%s' "$mock" | HOME="$fake" bash "$target_script") || die "self-test failed"
  rm -rf "$fake"
else
  out=$(printf '%s' "$mock" | bash "$target_script") || die "self-test failed"
fi
[ -n "$out" ] || die "self-test produced no output"
echo "• self-test render: $out"

# ---------- done: what you'll see ----------
cat <<'EOF'
✅ Installed. Restart your Claude Code session — the bar appears after the first turn.

   How to read it:   you:~/repo  Opus 4.8  ctx:12%  5h:27%  7d:8%
   ctx = context window used (fills as the conversation grows; quality degrades near 100%)
   5h / 7d = your two Claude rate-limit windows (the budgets that cut you off mid-task)

   Note: 5h/7d come from Claude.ai Pro/Max subscription limits and appear after the
   session's first response. On API-key billing those fields don't exist — you'll
   see ctx only, which is expected, not a bug.
EOF
