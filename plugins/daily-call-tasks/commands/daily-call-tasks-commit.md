---
argument-hint: "[--since=yesterday|today|Nd|YYYY-MM-DD] [--tz=IANA] [--dry-run]"
description: "Review/edit your call action-items in chat and create the chosen ones as ClickUp tasks (interactive, human-confirmed, self only)."
---

Invoke the `daily-call-tasks:daily-call-tasks-commit` skill via the Skill tool, passing `$ARGUMENTS` verbatim. The skill re-extracts your attended-call action items, lets you review/edit the list, and CREATES the chosen items as ClickUp tasks (or UPDATES a similar existing one) — interactive only, writes nothing until you confirm, self only. Requires a confirmed identity (run `/morning-brief --onboard` once if absent) and the ClickUp MCP.
