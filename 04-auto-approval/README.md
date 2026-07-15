# 4 · Interruption — "Stop asking me about obviously-safe things"

## The pain

By default, Claude Code asks permission before most actions it takes. That's the
right default — and it becomes the bottleneck the moment you use the tool
seriously. A single research task can generate a dozen Y/N prompts for
obviously-safe, read-only commands (`git diff`, `rg`, `npm ls`), and the constant
interruptions train people toward one of two bad outcomes: babysitting the
terminal, or switching everything off with `bypassPermissions` — which is exactly
the wrong move on a managed or client device.

The fix isn't "approve less carefully." It's making the *safe* approvals
automatic so the prompts you still see are the ones that deserve attention.

## Primer: the two mechanisms

**The allowlist.** `settings.json` accepts a `permissions.allow` array of
pre-approved tool patterns — exact commands (`Bash(git status)`), prefixes
(`Bash(git diff:*)`), or MCP tools (`mcp__github__list_issues`). Anything that
matches never prompts. Declarative, supported, no code. Rules live at user scope
(`~/.claude/settings.json`, all projects), project scope (`<repo>/.claude/settings.json`,
shared with the team via git), or local scope (`<repo>/.claude/settings.local.json`,
just you). `deny` rules always beat `allow` rules.

**The PermissionRequest hook.** When Claude Code is about to prompt you, it can
first run a script of yours, passing the request as JSON on stdin. If the script
prints an `allow`/`deny` decision, that's the answer; if it prints nothing, the
normal prompt appears. This is the same hook that powers remote phone approval
(section 3) — here it's used to make the decision locally.

## The ladder

Climb one rung at a time. Each is more convenient and more trusting than the last.

### Tier 0 — Starter allowlist

Merge [`allowlist-starter.json`](allowlist-starter.json) into your
`~/.claude/settings.json` (or add entries interactively with `/permissions`).
It pre-approves common read-only commands: git reads, search, file inspection.

Candidates to add once you know your stack — your linter, typechecker, and test
runner (`Bash(npm run lint)`, `Bash(npx tsc --noEmit)`, …). Two rules of thumb:

- **Narrow beats broad.** `Bash(git diff:*)` is safe; `Bash(git:*)` silently
  includes `git push`. Approve the subcommand, not the tool.
- **Never allowlist an interpreter.** `Bash(python3:*)` or `Bash(node:*)` is
  auto-approval of arbitrary code — the side door to YOLO mode.

### Tier 1 — Measure, then tune

Install [`hooks/log-permission-requests.sh`](hooks/log-permission-requests.sh)
(see [INSTALL.md](INSTALL.md)). It changes nothing — every prompt still appears —
but each one is recorded to a local JSONL file. After a week, mine the log for
your personal top interrupters and turn the safe ones into allowlist entries:
recipes and a copy-paste Claude prompt in [`analyze.md`](analyze.md).

This loop — log → analyze → narrow allowlist entry — is the sustainable version
of "fewer prompts." You're approving patterns you've actually seen, not guessing.

### Tier 2 — Auto-approve with a human-review denylist

> **Read [SECURITY.md](../SECURITY.md) first, and on a managed device, ask
> IT/security before installing this tier.**

[`hooks/auto-approve.sh`](hooks/auto-approve.sh) inverts the model: instead of
listing what's allowed, it lists what still *requires a human* and approves
everything else. The shipped needs-human list:

- Plan approvals and questions (`ExitPlanMode`, `AskUserQuestion`) — these are
  conversations, not permissions
- MCP tools that aren't clearly reads — i.e. anything that could write to
  Slack, GitHub, Jira, email…
- Shell commands that push, publish, escalate, or destroy: any `git … push`
  (flags between `git` and `push` are caught), `gh` write operations —
  including `gh api` with a write method or field flags — `sudo`, `rm` with
  a recursive or force flag, and `npm`/`yarn`/`pnpm … publish`

Needs-human cases fall through to the normal terminal prompt — or, if you've
set up section 3, to your phone. Every decision (auto and human) is appended to
the same audit log Tier 1 uses, so you can review what it waved through.

The needs-human list is a clearly-marked case block at the top of the script —
edit it to your risk tolerance. And you don't have to run it everywhere:
hooks configured in a repo's `.claude/settings.json` apply only in that repo,
so the enterprise-sane deployment is Tier 2 in trusted internal repos, Tiers
0–1 everywhere else.

## Why not just use the built-ins?

Claude Code ships several related features; know them before adding custom machinery.

| Option | What it does | Where this kit differs |
|---|---|---|
| `/fewer-permission-prompts` | Ships in recent versions (check `/help`): scans transcripts, proposes an allowlist | Try it first. Tier 1 adds an always-on log incl. MCP tools, and the Tier 2 audit trail |
| `acceptEdits` mode | Auto-approves file edits + safe filesystem commands | Doesn't cover Bash beyond "safe" commands or MCP; Tier 2 does, deterministically |
| `auto` mode | A background classifier validates each action | Model-mediated judgment; Tier 2 is a deterministic, self-auditable rule set you can show your security team |
| `dontAsk` mode | Auto-denies anything not pre-approved | The strict inverse posture — good for demos/unattended runs; pairs well with a tuned Tier 0/1 allowlist |
| `bypassPermissions` | Skips (almost) all checks | No human gate on anything — Tier 2 exists precisely to avoid this |

`deny` rules apply in every mode, so a team can pin hard "never" rules (e.g.
`Bash(git push:*)` in a project's shared settings) underneath any tier here.

## Windows?

- **Tier 0 is pure settings** — fully portable.
- **Tiers 1–2 are bash + jq.** On native Windows, Claude Code runs hook
  commands through Git Bash when it's installed (it generally is — Git for
  Windows is required for Claude Code desktop), falling back to PowerShell.
  Install jq (`winget install jqlang.jq`), write paths with forward slashes,
  and the scripts should run as-is. Caveat: the Git-Bash-vs-PowerShell rule is
  documented for statusline commands, and hooks are believed to follow the same
  logic — confirm on the first Windows install and tell the kit maintainer.

## Files

| File | Purpose |
|---|---|
| `allowlist-starter.json` | Tier 0 — conservative `permissions.allow` starter set |
| `hooks/log-permission-requests.sh` | Tier 1 — log-only PermissionRequest hook |
| `hooks/auto-approve.sh` | Tier 2 — auto-approve with needs-human denylist |
| `analyze.md` | jq recipes + prompts for turning the log into allowlist entries |
| `INSTALL.md` | Step-by-step install, macOS/Linux and Windows |
