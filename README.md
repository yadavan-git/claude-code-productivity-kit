# Claude Code Productivity Kit

Four small upgrades that remove the babysitting from Claude Code. Making the
tool genuinely productive turns out to be four separate sub-problems:

| # | Sub-problem | In one line | Section |
|---|---|---|---|
| 1 | **Visibility** | "How much runway do I have?" | [01-statusline](01-statusline/) |
| 2 | **Attention** | "Tell me when it's done." | [02-notify](02-notify/) |
| 3 | **Availability** | "Unblock it when I'm away from my desk." | [03-remote-approval](03-remote-approval/) |
| 4 | **Interruption** | "Stop asking me about obviously-safe things." | [04-auto-approval](04-auto-approval/) |

They're also a ladder — each rung is more valuable and more trusting than the
last, so start at 1 and climb at your own pace. Each section is self-contained:
its own problem statement, a short primer on the Claude Code concept it uses,
and install steps per OS.

Shared mechanics, once: clone this repo (or download it) and run each
section's install commands **from inside that section's folder** — they use
relative paths. **Windows users: run all install commands in Git Bash** (it
comes with Git for Windows), not PowerShell. Everything installs as files
under `~/.claude/` plus entries in `settings.json`; hooks and settings load
at session start, so **restart your Claude Code session after installing
anything**. Most scripts need `jq` (macOS: `brew install jq`; Windows:
`winget install jqlang.jq`).

**Installing with Claude Code?** That works well — point it at **one section
at a time** and be specific, e.g. tell it:

> *Read `01-statusline/INSTALL.md` in this repo and run its `./install.sh` for me.*

A vague "set this whole repo up" tends to make an agent attempt all four
sections in one pass — including the two that deserve a security read first.
Sections 1 and 2 ship an `install.sh`; for sections 3–4, have the agent follow
that section's INSTALL.md and **merge** any `settings.json` snippets into your
existing file (never paste them as the whole file).

Before installing sections 3 or 4 on a managed device, read
[SECURITY.md](SECURITY.md) — it's written to be forwarded to IT as-is.

---

## 1 · Visibility — "How much runway do I have?"

**Pain.** Claude Code meters usage in a 5-hour and a 7-day window, and every
conversation has a finite context window — all three run down invisibly until
you hit one mid-task.

**Primer.** `settings.json` takes a `statusLine` script; Claude Code re-runs
it every turn with session state (model, context %, both rate-limit windows)
as JSON on stdin, and whatever it prints becomes a persistent bar at the
bottom of your terminal.

**What you get.** A color-coded statusline —
`you:/Users/you/repo  Opus 4.8  ctx:12%  5h:27%  7d:8%` — plus, on macOS, an optional
menu-bar widget (SwiftBar) showing usage with reset countdowns even when no
terminal is visible.

**Windows?** Statusline: yes (runs via Git Bash; documented support). Menu-bar
widget: macOS-only.

**Get it:** [01-statusline/](01-statusline/) — one command: `./install.sh`
(add `--full` on macOS for the menu-bar widget).

## 2 · Attention — "Tell me when it's done."

**Pain.** Long turns mean you tab away — and Claude finished eight minutes
ago, or is sitting blocked on a question for you. The gap between "done" and
"noticed" is the biggest tax on agent workflows.

**Primer.** Custom slash commands (markdown files in `~/.claude/commands/`)
arm a per-session flag file; a `Stop` hook — a script that runs every time
Claude ends a turn — checks the flag and fires a notification.

**What you get.** `/notify-me [label]` (one-shot), `/notify-me-ongoing`
(every turn), `/notify-cancel`, plus two macOS-only refocus variants that also
raise the right Terminal tab without stealing focus. Native banners on macOS,
toasts on Windows.

**Windows?** The two core commands: yes, via a bundled no-module PowerShell
toast helper (pending first-user verification). Refocus variants: macOS-only.

**Get it:** [02-notify/](02-notify/) — one command: `./install.sh` (fires a
test notification so you see it working).

## 3 · Availability — "Unblock it when I'm away from my desk."

**Pain.** You start a long task and leave; Claude hits a permission prompt
and the run stalls until you return.

**Primer.** The `PermissionRequest` hook runs a script when Claude Code is
about to prompt — meaning the prompt can be answered from somewhere other
than your terminal. Like your phone.

**What you get.** Wiring for [claude-remote-approver](https://github.com/yuuichieguchi/claude-remote-approver)
(third-party, MIT) + the free ntfy app: permission prompts arrive as phone
pushes with Approve/Deny buttons; unanswered ones fall back to the terminal
after ~20–30s, so a session never wedges. **Security matters here** — prompts
transit an ntfy server; use a self-hosted one for client work. See
[SECURITY.md](SECURITY.md).

**Windows?** Node-based and should port; unverified — needs one pilot user.

**Get it:** [03-remote-approval/](03-remote-approval/)

## 4 · Interruption — "Stop asking me about obviously-safe things."

**Pain.** Claude Code asks Y/N before most actions. A single task can mean a
dozen prompts for obviously-safe, read-only commands — and prompt fatigue
pushes people toward the real hazard, switching permissions off entirely.

**Primer.** Two mechanisms: `permissions.allow` in `settings.json`, a
declarative list of pre-approved tool patterns; and the `PermissionRequest`
hook, a script that runs when Claude Code is about to prompt and may answer
"allow" itself (silence = the normal prompt appears).

**What you get.** A three-tier ladder: **Tier 0**, a conservative starter
allowlist for common read-only commands; **Tier 1**, a log-only hook that
records every prompt you hit, plus recipes to turn a week of data into narrow
allowlist entries; **Tier 2**, auto-approval of everything *except* a
needs-human denylist (plan approvals, MCP writes, `git push`, `sudo`,
`rm -rf`, publishes) with a local audit log — deployable per-repo so it only
runs where you trust it.

**Windows?** Tier 0 fully (pure settings). Tiers 1–2 run via Git Bash, which
Claude Code uses for hooks on Windows — details in the install guide.

**Get it:** [04-auto-approval/](04-auto-approval/) — README, INSTALL, scripts.

---

*Maintained by Yadavan — questions, fixes, and Windows pilot reports: open an
issue on this repo, or find me on the team chat. The canonical home of this
kit is `github.com/yadavan-git/claude-code-productivity-kit`; if you received
it any other way than from me or that URL, check with me before installing.*
