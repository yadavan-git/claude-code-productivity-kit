# 1 · Visibility — "How much runway do I have?"

## The pain

Claude Code meters usage in two windows — a 5-hour session budget and a 7-day
budget — and every conversation also has a finite context window. All three
run down invisibly. The failure modes are familiar to anyone who uses the tool
seriously: you hit the 5-hour limit mid-refactor with no warning, or a long
session's context fills up and quality quietly degrades before an
auto-compaction you didn't plan for. You can't manage a budget you can't see.

## Primer: the statusline

`settings.json` accepts a `statusLine` entry pointing at any script. Claude
Code re-runs it on every turn, feeding it session state as JSON on stdin —
model, working directory, **context-window %, and both rate-limit windows** —
and whatever the script prints becomes a persistent bar at the bottom of your
terminal. That's the whole mechanism: the data is already there; the script
just formats it.

## What you get

**Basic (everyone):** [`statusline.sh`](statusline.sh) renders
`user:directory  model  ctx:12%  5h:27%  7d:8%` — color-coded, updated every
turn. Portable macOS / Linux / Windows-Git-Bash; the only dependency is `jq`.

**Full tracker (macOS bonus):** the statusline payload dies with the terminal,
so [`macos/statusline-full.sh`](macos/statusline-full.sh) also persists each
reading to `~/.claude/usage-status.json` (with guards against stale
post-restart readings clobbering good data) plus an append-only history log —
and [`macos/claude-usage.30s.sh`](macos/claude-usage.30s.sh) is a
[SwiftBar](https://swiftbar.app) plugin that puts `CC 27%/8%` in your **menu
bar**, color-shifting white→amber→red, with reset countdowns in the dropdown.
Usage visibility without a terminal anywhere on screen.

## Windows?

The basic statusline: yes — statusline commands are documented to run through
Git Bash on Windows (PowerShell if Git Bash is absent); install `jq` and use
forward slashes in the settings path. The menu-bar widget: no — SwiftBar is
macOS-only and there's no equivalent worth building; the statusline alone
carries most of the value.

## Files

| File | Purpose |
|---|---|
| `statusline.sh` | Portable statusline (render only) |
| `macos/statusline-full.sh` | Statusline + persistence for the widget (macOS) |
| `macos/claude-usage.30s.sh` | SwiftBar menu-bar widget (macOS) |
| `INSTALL.md` | Step-by-step install |
