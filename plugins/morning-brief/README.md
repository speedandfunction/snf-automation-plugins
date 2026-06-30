# morning-brief

**One interactive command** that prepares your daily standup and posts it to Geekbot (→ Slack).
It runs the `daily-call-tasks` call-extraction first (as a Sonnet-backed source), then reads your
own ClickUp + Calendar (+ Gmail if connected) and walks you through a single flow that ends in a
confirmed Geekbot post. Self-contained — it carries its own copy of the call-extraction reference;
no cross-plugin imports.

> Companion to the `daily-call-tasks` plugin (digest + commit). Shares the
> `~/.claude/shared/identity.json` contract that `/clickup`, `/gevent`, and `daily-call-tasks`
> use. ClickUp 86cacn12x.

## The flow (`/morning-brief`)
1. **Source step** — runs the call extraction (attended calls → Meeting Notes → **Sonnet** sub-agents) for the window, kept as the call-items source.
2. **Status-management** — lists **ALL your tasks grouped by status** (Closed / In Progress / In Review / To-Do / Blocked) with one continuous unique number, and asks *"what to change?"*. You command changes (`3→on hold, 4→done, 2→backlog`); it maps each verb to a real workspace status and, after a preview, **APPLIES them in ClickUp** (`clickup_update_task`, status field only). A task you move to **Closed** feeds *what was done*.
3. **What was done** — attended calls (grouped) + **Closed** tasks + In Progress / In Review transitions since the window, *including the changes you just applied*. ("Sent for review *to whom*" is resolved from the task's assigned comment.)
4. **On your plate today** — current **In Progress + To-Do** (+ not-yet-ticketed call items, flagged `⟂ not yet in ClickUp`), numbered. You pick which to report (`1,3,7`) — to-dos are a weekly bucket, not all for today.
5. **Blockers WITH the reason** — *"`<task>` is blocked because `<reason>`"* (from the status / the comment recorded when it was blocked); you can add extra reasons.
6. **Open questions** — your own, and to whom (resolved to `<@SlackID>` via a `team.md` roster).
7. **Mood** — picked from your standup's **real Geekbot mood options** when a Geekbot key is connected (read live from the Geekbot API); otherwise a sensible default set (the five Andy configured), never invented per-run.
8. **Post to Geekbot** — preview the exact payload, then post (→ Slack), with each task's ClickUp ticket id kept for quick search.

```text
/morning-brief        # full interactive run → status changes → sections → post
```
No flags: setup (identity + dependencies) is **transparent on first run**; a **scheduled** run auto-uses **yesterday, read-only** (no prompts, no writes), a **manual** run **asks the period**.

> First release: the Geekbot auto-post path hasn't been exercised end-to-end — preview carefully on the first live run.

## Requirements
- **Required:** the **ClickUp MCP** (load-bearing), and the Google **Calendar** + **Drive** connectors (the call source + attended meetings). Per-call sub-agents run on **Sonnet** (`CLAUDE_CODE_SUBAGENT_MODEL=claude-sonnet-4-6`).
- **One-time identity:** created transparently on first run — a self-contained wizard writes `~/.claude/shared/identity.json` (no other plugin required; this also unblocks `daily-call-tasks`).
- **Optional (degrade gracefully if absent):** a **Geekbot** API key (`GEEKBOT_API_KEY` or `~/.claude/morning-brief/config.json` → `geekbot.api_key`) for auto-post + real mood options; the **Gmail** connector for the Emails plate-items; a `~/Work/team.md` roster for `<@SlackID>` mentions.

## Guarantees
- **Read-only except two user-commanded writes:** the ClickUp status changes you explicitly type in the status step (status field only, after a preview), and the **confirmed** Geekbot post. Plus local-only writes: the self-onboarded identity file and a state snapshot under `~/.claude/morning-brief/`.
- **Self only** — speaks for you, never assigns or @-mentions on anyone else's behalf; **fails closed** on any unresolved mention rather than post a broken `@`.
- **Never invents** — call items carry verbatim citations; a blocker with no recorded reason says so; a verb that doesn't map to a real status is asked, never guessed.
- **Never creates/edits** ClickUp task name/description/assignee here (that's `daily-call-tasks`) — the only ClickUp write is the status change you command.

## Layout
This is a **command plugin** — the instruction body lives in `commands/morning-brief.md`, which Claude Code registers as the clean bare command `/morning-brief` (NOT a namespaced `/morning-brief:morning-brief`). A plugin SKILL (root or `skills/<name>/`) is always namespaced; only a COMMAND is bare. Do not "restore" a `SKILL.md`/`skills/` tree — that re-breaks bare invocation.
```
morning-brief/
  commands/morning-brief.md      # the command (instruction body) → bare /morning-brief
  .claude-plugin/plugin.json     # plugin manifest
  README.md
  references/
    onboarding.md
    extraction.md
    sections.md
```
- `references/onboarding.md` — the self-contained identity wizard + atomic/flock write helper.
- `references/extraction.md` — morning-brief's own copy of the Sonnet call-extraction primitives (rules are inlined into each sub-agent prompt at spawn time).
- `references/sections.md` — status-verb→status mapping + safe apply (frozen number→id map), snapshot-diff "what was done", plate dedup, block-reason derivation, the TeamMD resolver, the real-Geekbot-mood read, the payload sanitizer, and the Geekbot payload.
