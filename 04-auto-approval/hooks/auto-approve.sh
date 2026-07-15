#!/usr/bin/env bash
# PermissionRequest hook — Tier 2: auto-approve with a human-review denylist.
#
# READ ../../SECURITY.md BEFORE INSTALLING. This hook approves most tool
# calls without asking you. It is meant for people who have already run
# Tier 1 for a while and understand what they're waving through.
#
# Behavior:
#   - Auto-approves every permission request EXCEPT the needs-human cases
#     matched below (plan approvals, questions, MCP writes, and shell
#     commands that push, publish, escalate, or destroy).
#   - needs-human cases: delegated to CLAUDE_REMOTE_APPROVER if configured
#     (phone push approval — see ../../03-remote-approval/), otherwise the
#     hook stays silent and Claude Code shows its normal terminal prompt.
#   - Every decision is appended to a local JSONL audit log.
#
# Dependencies: bash, jq. Fails safe: if jq is missing or the payload is
# unparseable, the hook stays silent and normal prompting resumes.
#
# Config (env vars, or edit the defaults here):
#   CLAUDE_PERMISSION_LOG    default: ~/.claude/permission-requests.jsonl
#   CLAUDE_REMOTE_APPROVER   optional command for needs-human cases; gets the
#                            hook payload on stdin and must print a
#                            PermissionRequest decision on stdout, e.g.
#                            "/usr/local/bin/node /path/to/claude-remote-approver/bin/cli.mjs hook"

set -o pipefail

LOG="${CLAUDE_PERMISSION_LOG:-$HOME/.claude/permission-requests.jsonl}"

TMPIN=$(mktemp)
TMPOUT=$(mktemp)
trap 'rm -f "$TMPIN" "$TMPOUT"' EXIT

cat > "$TMPIN"

# Fail safe: no jq, or a payload we can't parse -> stay silent so Claude
# Code falls back to its normal interactive prompt.
command -v jq >/dev/null 2>&1 || exit 0
TOOL_NAME=$(jq -r '.tool_name // ""' "$TMPIN" 2>/dev/null)
[ -z "$TOOL_NAME" ] && exit 0
COMMAND=$(jq -r '.tool_input.command // ""' "$TMPIN" 2>/dev/null)

# ---------------------------------------------------------------------------
# The needs-human list. Everything NOT matched here gets auto-approved —
# edit this block to match your team's risk tolerance. Shipped defaults
# keep a human in the loop for:
#   - ExitPlanMode / AskUserQuestion  (intrinsically user-facing)
#   - MCP tools that aren't clearly reads (i.e. writes to Slack/GitHub/...)
#   - Bash commands that publish, push, escalate, or destroy — any git push,
#     gh writes (incl. gh api with a write method or field flags), sudo,
#     rm with a recursive/force flag, npm/yarn/pnpm publish
# Note this is a denylist, not a sandbox: a sufficiently creative command
# can evade regexes. See ../../SECURITY.md for the threat model.
# ---------------------------------------------------------------------------
needs_human=0
case "$TOOL_NAME" in
  ExitPlanMode|AskUserQuestion)
    needs_human=1
    ;;
  mcp__*__get_*|mcp__*__list_*|mcp__*__search_*|mcp__*__read_*|mcp__*__describe_*)
    : # MCP reads auto-approve
    ;;
  mcp__*)
    needs_human=1   # any MCP tool not matched as a read is treated as a write
    ;;
  Bash)
    # Patterns tolerate flags between the tool and its verb (git -C x push,
    # pnpm -r publish, gh api --method POST / implied-POST via field flags),
    # since those are the forms an agent actually emits.
    if echo "$COMMAND" | grep -qE '(^|[[:space:];|&(`])git([[:space:]]+[^;|&[:space:]]+)*[[:space:]]+push([[:space:];|&)]|$)' \
       || echo "$COMMAND" | grep -qE '(^|[[:space:];|&(`])gh[[:space:]]+(pr|issue|release|repo|secret|gist|workflow|label|ssh-key|variable|cache|ruleset|codespace|environment)[[:space:]]+(create|edit|delete|merge|close|reopen|comment|review|ready|set|remove|add|run|enable|disable|fork|archive|unarchive|rename|sync|upload|transfer|pin|unpin|lock|unlock)\b' \
       || echo "$COMMAND" | grep -qE '(^|[[:space:];|&(`])gh[[:space:]]+api\b.*(-X[[:space:]]*|--method[[:space:]=]+)(POST|PUT|PATCH|DELETE)\b' \
       || echo "$COMMAND" | grep -qE '(^|[[:space:];|&(`])gh[[:space:]]+api\b.*[[:space:]](-f|-F|--field|--raw-field|--input)([[:space:]=]|$)' \
       || echo "$COMMAND" | grep -qE '(^|[[:space:];|&(`])sudo[[:space:]]' \
       || echo "$COMMAND" | grep -qE '(^|[[:space:];|&(`])rm[[:space:]]([^;|&]*[[:space:]])?(-[a-zA-Z]*[rf]|--recursive\b|--force\b)' \
       || echo "$COMMAND" | grep -qE '(^|[[:space:];|&(`])(npm|yarn|pnpm)([[:space:]]+[^;|&[:space:]]+)*[[:space:]]+publish([[:space:];|&)]|$)'; then
      needs_human=1
    fi
    ;;
esac

if [ "$needs_human" = "1" ]; then
  if [ -n "${CLAUDE_REMOTE_APPROVER:-}" ]; then
    # Deliberately unquoted: CLAUDE_REMOTE_APPROVER is a command line
    # (binary + args), not a single path.
    $CLAUDE_REMOTE_APPROVER < "$TMPIN" > "$TMPOUT"
    EXIT_CODE=$?
    DECISION="human_remote"
    if [ "$EXIT_CODE" -ne 0 ]; then
      # Approver crashed or errored — fail safe to the normal terminal
      # prompt instead of emitting partial output or a nonzero exit.
      : > "$TMPOUT"
      EXIT_CODE=0
      DECISION="human_prompt_fallback"
    fi
  else
    : > "$TMPOUT"   # silent -> Claude Code shows its normal prompt
    EXIT_CODE=0
    DECISION="human_prompt"
  fi
else
  printf '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}\n' > "$TMPOUT"
  EXIT_CODE=0
  DECISION="auto_allow"
fi

# "Intent" of a Bash command: strip leading `cd "..." &&` and VAR=value
# assignments to expose the real executable. Non-Bash tools log the tool name.
CMD_INTENT=$(jq -r '
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
' "$TMPIN" 2>/dev/null)

ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
jq -c \
  --arg ts "$ts" \
  --arg decision "$DECISION" \
  --arg cmd_intent "${CMD_INTENT:-}" \
  '{schema: 1, ts: $ts, decision: $decision, cmd_intent: $cmd_intent,
    tool_name: (.tool_name // ""),
    command: ((.tool_input.command // null) | if type == "string" then .[0:500] else . end),
    file_path: (.tool_input.file_path // null)}' "$TMPIN" >> "$LOG" 2>/dev/null

cat "$TMPOUT"
exit $EXIT_CODE
