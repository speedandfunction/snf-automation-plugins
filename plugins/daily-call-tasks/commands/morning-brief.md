---
argument-hint: "[--since=yesterday|Nd|YYYY-MM-DD] [--tz=IANA] [--onboard] [--status] [--no-post]"
description: "Interactive Geekbot-style standup prep: what you did / what's on your plate / blockers / open questions, then auto-post to Geekbot with correct Slack mentions."
---

Invoke the `daily-call-tasks:morning-brief` skill via the Skill tool, passing `$ARGUMENTS` verbatim. The skill assembles your standup brief from the calls you attended + your own ClickUp tasks (status changes, on-your-plate, blockers, not-yet-ticketed call items), asks your open questions, and on explicit confirmation auto-posts to Geekbot with correct `<@SlackID>` mentions. Read-only against ClickUp/Calendar/Drive; the only writes are the self-onboarded identity file and the confirmed Geekbot post. `--onboard` runs only the one-time identity wizard; `--status` prints the dependency checklist.
