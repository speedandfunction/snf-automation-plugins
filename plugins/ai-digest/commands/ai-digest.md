---
argument-hint: "[--week=last|this|YYYY-Www|YYYY-MM-DD] [--dry-run] [--tz=IANA] [--max-subagents=N] [--setup]"
description: "Draft a weekly cross-dept AI-Automation digest (top-3 closed / in-progress / priorities) from the dept's meeting-notes + ClickUp (+ optional Geekbot). Cited, print-only. Use --setup to enable Geekbot locally. Read-only."
---

Invoke the `ai-digest:ai-digest` skill via the Skill tool, passing `$ARGUMENTS` verbatim. Default: the skill reads the AUT meeting-notes (primary narrative) + the AUT ClickUp space (the dated "what closed" signal) — plus Geekbot if configured — for the target ISO week, builds a cited three-section draft (Closed this week / Discussed-in-progress / Priorities), prints a clean reader copy + an audit/editor file, and stops. Read-only against all data sources; never writes to Drive/ClickUp/Slack/Geekbot; makes NO "verified" claims; every line is cited. With `--setup`, it runs an INTERACTIVE flow to enable the optional Geekbot source locally (the API key stays in the user's home folder, never in the repo, never printed) — the only mode that writes (just the local `~/.claude/ai-digest/config.md`, on confirmation).
