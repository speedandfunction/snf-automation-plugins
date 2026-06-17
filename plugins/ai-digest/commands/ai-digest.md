---
argument-hint: "[--week=last|this|YYYY-Www|YYYY-MM-DD] [--dry-run] [--tz=IANA] [--max-subagents=N]"
description: "Draft a weekly cross-dept AI-Automation digest (top-3 closed / in-progress / priorities) from the dept's meeting-notes + ClickUp. Cited, print-only — a human edits, the lead publishes. Read-only."
---

Invoke the `ai-digest:ai-digest` skill via the Skill tool, passing `$ARGUMENTS` verbatim. The skill reads the AUT meeting-notes (primary narrative) + the AUT ClickUp space (the dated "what closed" signal) for the target ISO week, builds a cited three-section draft (Closed this week / Discussed-in-progress / Priorities), prints a clean reader copy + an audit/editor file, and stops. Read-only — never writes to Drive, ClickUp, Slack, or anywhere. Makes NO "verified" claims; every line is cited.
