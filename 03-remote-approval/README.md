# 3 · Availability — "Unblock it when I'm away from my desk."

## The pain

You kick off a long task — a migration, a big refactor, a research sweep — and
walk to a meeting. Ten minutes in, Claude hits a permission prompt and the
whole run stalls until you're back at the keyboard. The agent can work
unattended; the *approval* can't. (Section 4 removes prompts for safe actions;
this section handles the prompts that legitimately remain.)

## Primer: the PermissionRequest hook

When Claude Code is about to show a Y/N permission prompt, it first runs any
script registered under `hooks.PermissionRequest`, passing the request as JSON
on stdin. If the script prints an allow/deny decision, that's the answer — the
terminal prompt never appears. Which means the "screen" the prompt appears on
doesn't have to be your terminal at all. It can be your phone.

## What you get

[`claude-remote-approver`](https://github.com/yuuichieguchi/claude-remote-approver)
(third-party, MIT, Node ≥18 — we just wire it in) plus the free
[ntfy](https://ntfy.sh) push app:

1. Claude hits a permission prompt → the hook publishes it to your private
   ntfy topic → your phone buzzes with the command text and **Approve /
   Always Approve / Deny** buttons.
2. You tap; the decision travels back on a response topic; Claude continues
   within a second or two.
3. You ignore it (meeting, no signal, phone in bag) → after a short timeout
   (~20–30s) the hook gives up and the **normal terminal prompt appears** — a
   session can never wedge on this.

Setup generates a random topic ID with 128 bits of entropy and prints a QR
code; scan it with the ntfy app and you're subscribed.

## Read before installing on a work machine

The pushed notifications contain **command text and file paths**. On the
default public ntfy.sh server, topic secrecy is the only access control —
treat anything pushed through it as potentially public.

- **Personal machine / personal projects:** public ntfy.sh is a reasonable
  trade; the topic is unguessable.
- **Client or employer data:** use a **self-hosted ntfy server** — it's a
  first-class option (`ntfyServer` in `~/.claude-remote-approver.json`), with
  Basic Auth supported for authenticated topics. A corp ntfy instance is a
  one-container deployment IT can own. Ask before routing anything through
  the public server.

More detail in [SECURITY.md](../SECURITY.md), written to be forwarded to IT.

## Plays well with section 4

Standalone, the approver handles *every* permission prompt — that's a lot of
phone taps. The combo is where it shines: section 4's Tier 2 auto-approves the
safe majority locally and delegates only its needs-human list (git push, MCP
writes, plan approvals) to your phone. Install order: this section first,
confirm it works, then layer Tier 2 over it (its INSTALL covers the wiring).

## Windows?

The tool is Node and should be portable, but it's **unverified on Windows by
us** — its installer registers the hook in `settings.json` itself, and how
that interacts with Git-Bash-vs-PowerShell hook execution needs one pilot
user's confirmation. The phone side is identical either way.

## Files

No scripts of ours — the tool is upstream. [`INSTALL.md`](INSTALL.md) covers
install, phone setup, self-hosting, and the section-4 combo.
