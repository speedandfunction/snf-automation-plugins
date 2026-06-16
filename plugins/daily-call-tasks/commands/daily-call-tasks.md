---
argument-hint: "[--since=yesterday|today|Nd|YYYY-MM-DD] [--dry-run] [--tz=IANA]"
description: "Print a cited digest of the action items from the calls you personally attended (default: yesterday). Read-only, unattended-safe."
---

Invoke the `daily-call-tasks:daily-call-tasks` skill via the Skill tool, passing `$ARGUMENTS` verbatim. The skill reads your Google Calendar for attended events, pulls the notes-bot Meeting Notes/transcript, and extracts YOUR action items with citations. Read-only — never writes to Calendar/Drive/ClickUp/Slack.
