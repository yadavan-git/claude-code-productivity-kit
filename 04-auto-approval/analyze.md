# Mining the permission log

After running the Tier 1 hook for a few days (a week is better), the JSONL log at
`~/.claude/permission-requests.jsonl` tells you exactly what you get interrupted by.
Each line looks like:

```json
{"schema":1,"ts":"2026-07-15T14:44:03Z","decision":"prompt","cmd_intent":"git","tool_name":"Bash","command":"git diff --stat","file_path":null}
```

`cmd_intent` is the real executable of a Bash command (leading `cd ... &&` and
`VAR=value` prefixes stripped), so compound commands group correctly.

## Recipes

Most frequent interruptions, by command intent:

```bash
jq -r '.cmd_intent' ~/.claude/permission-requests.jsonl | sort | uniq -c | sort -rn | head -20
```

Same, by tool (catches MCP tools, Edit/Write, etc.):

```bash
jq -r '.tool_name' ~/.claude/permission-requests.jsonl | sort | uniq -c | sort -rn | head -20
```

See the full commands behind one intent before allowlisting it (do this —
`git` frequency includes both `git diff` and `git push`):

```bash
jq -r 'select(.cmd_intent=="git") | .command' ~/.claude/permission-requests.jsonl | sort | uniq -c | sort -rn
```

If you're running Tier 2, audit what it auto-approved:

```bash
jq -r 'select(.decision=="auto_allow") | .cmd_intent' ~/.claude/permission-requests.jsonl | sort | uniq -c | sort -rn
```

## Turning findings into allowlist entries

The judgment call, per candidate: *is every command matching this pattern safe to
run without me seeing it?* Prefer the narrowest pattern that kills the noise —
`Bash(git diff:*)`, never `Bash(git:*)` (which would silently include `git push`).

Fastest path: paste the frequency output into Claude Code and ask —

> Here are my most frequent permission prompts. Propose `permissions.allow`
> entries for the ones that are safe to auto-approve, using the narrowest
> pattern for each, and tell me which ones you deliberately left out and why.

Then add the entries via `/permissions` or by editing `~/.claude/settings.json`.

## Note: the built-in

Recent Claude Code versions ship a `/fewer-permission-prompts` command
(check `/help` for it), which scans your transcripts and proposes an
allowlist — try it first; it may be all you need. The log-based loop here remains useful
on top of it: it captures exactly the prompts that fired (including MCP tools),
accumulates across all projects for as long as you leave it on, and doubles as
the audit trail for Tier 2.
