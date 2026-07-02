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
1. **Calls → ClickUp** — extracts action items from your attended calls (Meeting Notes → **Sonnet** sub-agents), shows them, asks *"add these to ClickUp?"* → on approval **creates the chosen tasks** (self-only, marker-dedup, one confirm).
2. **Status-management** — lists **ALL your tasks grouped by status** with one continuous number, asks *"what to change?"*; you command changes (`3→done, 4→on hold`) and it **APPLIES them in ClickUp** (status field only, after a preview). A task you move to **Closed** feeds *what was done*.
3. **Mood** — picked from your standup's **real Geekbot mood options** (live when a key is connected; else the five Andy configured), posted verbatim as Geekbot Q1.
4. **What was done** — attended calls (grouped) + Closed/changed tasks since the window (incl. what you just applied); you **approve** the report. ("Sent for review *to whom*" from the task's assigned comment.)
5. **On your plate today** — **today's calendar** + current **In Progress + To-Do** (+ In Review candidates + any declined call-items), numbered; you pick which to report.
6. **Blockers (with reason) + On-Hold** — *"`<task>` is blocked because `<reason>`"*; **the reason comes from YOU** (no ClickUp API returns block history) — the step asks for it.
7. **Open questions** — your own, and to whom (resolved to `<@SlackID>` via a `team.md` roster).
8. **Post to Geekbot** — preview the exact payload in your standup order (Mood → done → plate → blockers → questions), then post (→ Slack), with clickable ClickUp task links.

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
- **Writes only what you command:** the **Step-1 call-tasks you approve to create** (self-only, marker-dedup), the ClickUp status changes you type in the status step (status field only, after a preview), and the **confirmed** Geekbot post. Plus local-only writes: the self-onboarded identity file and a state snapshot under `~/.claude/morning-brief/`.
- **Self only** — speaks for you, never assigns or @-mentions on anyone else's behalf; **fails closed** on any unresolved mention rather than post a broken `@`.
- **Never invents** — call items carry verbatim citations; a blocker with no recorded reason says so; a verb that doesn't map to a real status is asked, never guessed.
- **Step 1 creates the call-tasks you approve** (self-only, marker-dedup); beyond that it never EDITS an existing task's name/description/assignee (that stays `daily-call-tasks`). The ClickUp writes are: the Step-1 create + the status changes you command.

## Layout
The skill lives at `skills/morning-brief/SKILL.md` (user-invocable). Claude Code namespaces every plugin component, so it invokes as `/morning-brief:morning-brief` OR via natural language ("run morning-brief") — there is no bare `/morning-brief` for a marketplace plugin (a Claude Code limitation).
```
morning-brief/
  skills/morning-brief/SKILL.md   # the skill (user-invocable) → /morning-brief:morning-brief or natural language
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
