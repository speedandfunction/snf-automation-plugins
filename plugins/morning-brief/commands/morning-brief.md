---
argument-hint: ""
description: "Interactive standup prep, one command: status-management (apply ClickUp status changes you command) → what was done → on your plate → blockers with reasons → your open questions + a real Geekbot mood → post to Geekbot (Slack)."
---

Invoke the `morning-brief` skill via the Skill tool.

It first runs the daily-call-tasks call-extraction (Sonnet sub-agents) as a source, then reads your own ClickUp + Calendar (+ Gmail if connected) and walks you through ONE flow:
1. **Status-management** — lists ALL your tasks grouped by status (Closed / In Progress / In Review / To-Do / Blocked) with continuous numbers; you command changes (e.g. `3→on hold, 4→done, 2→backlog`) and it APPLIES them in ClickUp after a preview.
2. **What was done** — attended calls + Closed tasks + the status transitions (including the ones you just applied).
3. **On your plate today** — In Progress + To-Do (+ not-yet-ticketed call items); you pick which to report.
4. **Blockers with the block reason**; you can add extra reasons.
5. **Open questions** (your own; to whom) + a **Mood** chosen from your standup's REAL Geekbot options.
6. **Post to Geekbot** (→ Slack) after a preview, with correct `<@SlackID>` mentions and each task's ClickUp ticket id.

No flags: setup (identity + dependencies) is transparent on first run; a scheduled run auto-uses yesterday read-only, a manual run asks the period. Read-only except the ClickUp status changes you command and the confirmed Geekbot post; self only; fails closed on any unresolved @mention.
