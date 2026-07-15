# Security notes — for you and your IT/security team

This page is written to be forwarded as-is to whoever owns endpoint or AI-tool
policy. It describes exactly what the kit's riskier pieces do, what data they
touch, and how to deploy them conservatively.

Sections 1 (statusline) and 2 (completion notifications) are passive — they read
session metadata Claude Code already exposes and write only local files. The two
that deserve review are below.

## Section 4 — permission auto-approval

**What Claude Code does by default.** Before running a shell command, editing a
file, or calling an integration (MCP tool), Claude Code asks the user Y/N.

**What each tier changes.**

- **Tier 0 (allowlist):** uses Claude Code's built-in, supported
  `permissions.allow` setting to pre-approve specific command patterns
  (e.g. `git diff`, `rg`). Narrow, declarative, inspectable. No custom code runs.
- **Tier 1 (logging):** a hook script records each would-be permission prompt
  to a local file (`~/.claude/permission-requests.jsonl`), then lets the normal
  prompt appear. **No behavior change.** The log contains tool names and command
  text — it stays on the device, is written by the user's own account, and
  nothing is transmitted anywhere.
- **Tier 2 (auto-approve):** a hook script approves tool calls automatically
  *except* a "needs-human" list that always still prompts: plan approvals and
  questions to the user, anything that writes through an integration
  (Slack/GitHub/Jira/…), and shell commands that push, publish, escalate, or
  destroy — any `git … push` (flag-tolerant matching), `gh` write operations
  including `gh api` with a write method or field flags, `sudo`, `rm` with a
  recursive or force flag, and `npm`/`yarn`/`pnpm publish`. Every decision is
  appended to the same local audit log.

**Tier 2 threat model, stated plainly.** The needs-human list is a denylist of
regex/glob patterns, not a sandbox. A sufficiently obfuscated command can evade
pattern-matching, and auto-approved reads can still access anything the user's
account can. Mitigations, in the order they matter:

1. It runs with the user's existing OS permissions — it grants the agent
   nothing the user couldn't already do at the same prompt by pressing "y".
2. `permissions.deny` rules are evaluated by Claude Code itself, before any
   hook, in every mode — hard "never" rules (e.g. deny `git push`, deny reads
   of a secrets directory) can be pinned in managed or project settings and
   this kit cannot override them.
3. Scoping: hooks placed in a repo's `.claude/settings.json` apply only inside
   that repo. Recommended deployment is Tier 2 in designated internal repos
   only, never machine-wide on a device that touches client data.
4. The audit log records everything auto-approved, for after-the-fact review.

**Compared to the built-in alternatives:** Tier 2 is strictly more conservative
than Claude Code's `bypassPermissions` / `--dangerously-skip-permissions`
(which keep no human gate at all), and unlike the built-in `auto` mode (an
ML classifier judging each action) it is a deterministic rule set that can be
read, diffed, and approved by a security reviewer.

**Recommended posture for a new team:** Tiers 0–1 for everyone immediately —
they are supported-configuration-only plus a local log. Tier 2 case-by-case,
per-repo, after IT sign-off.

## Section 3 — remote approval via ntfy

**What it does.** A third-party MIT-licensed tool
([claude-remote-approver](https://github.com/yuuichieguchi/claude-remote-approver),
Node ≥18) pushes each permission prompt to the user's phone via
[ntfy](https://ntfy.sh) (HTTP pub-sub push). The user taps Approve/Deny; the
decision returns on a response topic. Unanswered requests time out after
~20–30 seconds and fall back to the normal terminal prompt, so approval
authority never leaves the user — only its location changes.

**What the data path looks like.** Notification payloads contain the **tool
name, command text, and file paths** of the pending action. They transit the
configured ntfy server over TLS and are held by it for delivery (the public
ntfy.sh service caches messages server-side, ~12h by default). Access control
on the default public server is **topic secrecy only**: a randomly generated
topic ID with 128 bits of entropy, stored in a `0600` config file. Unguessable
in practice, but there is no authentication — anyone who obtains the topic ID
can read pushes and, on the response topic, answer them.

**Deployment guidance, in order of preference for a corporate device:**

1. **Self-hosted ntfy server** (first-class config option: `ntfyServer`), with
   Basic-Auth-protected topics (`ntfyUsername`/`ntfyPassword`). ntfy is a
   single-container open-source deployment IT can own and place behind the VPN.
2. Public ntfy.sh **only** on personal machines with non-sensitive projects,
   with the understanding that payloads should be treated as potentially
   public.
3. If neither is acceptable: skip section 3 entirely — section 4's Tiers 0–1
   still remove most prompt friction with no network component at all.

## Data inventory

| Data | Where | Leaves the device? |
|---|---|---|
| Permission request payloads (tool name, command text, file paths) | `~/.claude/permission-requests.jsonl` (§4 log) | No |
| Decisions (auto vs human) | same file | No |
| Permission prompts routed to phone (§3 only) | configured ntfy server + phone | **Yes — by design.** Public ntfy.sh or self-hosted per guidance above |
| Notification events (§2: session name, label) | `~/.claude/notify-events.jsonl` | No |
| Usage percentages (§1: rate-limit/context %, model name) | `~/.claude/usage-status.json` + history | No |
