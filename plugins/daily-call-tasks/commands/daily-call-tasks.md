---
argument-hint: "[period e.g. yesterday | today | last 3 days | 2026-06-20 | a range] [participants/team filter] [--tz=IANA]"
description: "Call action items as one table per meeting (№ | task | priority | status | deadline | assignee | description, continuous numbering). Scheduled → read-only for yesterday; manual → asks the period (+ optional team filter), then offers to push the chosen tasks to ClickUp."
---

Invoke the `daily-call-tasks:daily-call-tasks` skill via the Skill tool, passing `$ARGUMENTS` verbatim.

The skill reads your Google Calendar for the calls you attended, pulls each event's notes-bot Meeting Notes/transcript, and uses Sonnet sub-agents to extract action items with citations — then renders ONE table per meeting (heading = meeting name · date+time · participants; columns `№ | task name | priority | status | deadline | assignee | description`; numbering continuous across all tables).

- **Scheduled / unattended:** window = yesterday, tables only, read-only — never asks, never writes.
- **Manual / interactive:** asks the period (+ optional participants/team filter), renders the tables, then offers "add to ClickUp / fix anything?". You reply with task numbers + edits (`edit 4: …`, `prio 5: high`, `status 3: backlog`, `assignee 6: <name>`, `drop 7`) and `push to ClickUp` to create the chosen tasks in the automation space (status/priority/deadline/assignee set; team-assign allowed, confirmed; idempotent re-runs).

The ClickUp push requires the ClickUp MCP and your explicit confirmation; extraction is read-only.
