#!/usr/bin/env bash
# PermissionRequest hook — Tier 1: observe only.
#
# Logs every permission prompt Claude Code was about to show you to a local
# JSONL file, then stays silent so the normal interactive prompt appears.
# Changes nothing about behavior — run it for a week, then mine the log for
# allowlist candidates (see ../analyze.md).
#
# Dependencies: bash, jq. Exits 0 on every path so it can never block a session.
#
# Config:
#   CLAUDE_PERMISSION_LOG   log file (default: ~/.claude/permission-requests.jsonl)

LOG="${CLAUDE_PERMISSION_LOG:-$HOME/.claude/permission-requests.jsonl}"

payload=$(cat)

# No jq -> nothing we can do; stay silent and let the prompt happen.
command -v jq >/dev/null 2>&1 || exit 0

# "Intent" of a Bash command: strip leading `cd "..." &&` and VAR=value
# assignments to expose the real executable (so `cd /x && git push` counts
# as `git`, not `cd`). For non-Bash tools, intent is the tool name.
cmd_intent=$(printf '%s' "$payload" | jq -r '
  def strip_prefixes:
    sub("^cd \"[^\"]*\" *&& *"; "")
    | sub("^cd [^ ]+ *&& *"; "")
    | sub("^export [A-Z_][A-Za-z0-9_]*=(\"[^\"]*\"|'\''[^'\'']*'\''|[^ ]+) *&& *"; "")
    | gsub("^([A-Z_][A-Za-z0-9_]*=(\"[^\"]*\"|'\''[^'\'']*'\''|[^ ]+) +)+"; "")
    | sub("^&& *"; "")
    | sub("^; *"; "")
    | sub("^\\| *"; "");
  def first_token:
    (capture("^(?<q>\"[^\"]+\"|'\''[^'\'']+'\''|\\S+)") | .q
     | gsub("^[\"'\'']|[\"'\'']$"; ""));
  if .tool_name == "Bash" then
    ((.tool_input.command // "") | split("\n")[0]
     | strip_prefixes | strip_prefixes | strip_prefixes
     | first_token)
  else (.tool_name // "") end
' 2>/dev/null)

ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
printf '%s' "$payload" | jq -c \
  --arg ts "$ts" \
  --arg cmd_intent "${cmd_intent:-}" \
  '{schema: 1, ts: $ts, decision: "prompt", cmd_intent: $cmd_intent,
    tool_name: (.tool_name // ""),
    command: ((.tool_input.command // null) | if type == "string" then .[0:500] else . end),
    file_path: (.tool_input.file_path // null)}' >> "$LOG" 2>/dev/null

# Print nothing: no decision means Claude Code shows its normal prompt.
exit 0
