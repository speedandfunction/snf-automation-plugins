---
argument-hint: "[team tag or name] (e.g. 'AUT:MNB', 'two labs') — empty lists all teams"
description: "Resolve an MN Service team to its Google Drive transcript/notes folder link (live from the n8n MN Service config). Read-only."
---

Invoke the `mn-team-links:mn-team-links` skill via the Skill tool, passing `$ARGUMENTS` verbatim as the team query. The skill reads `teamsRaw` live from the n8n MN Service config (via the connected n8n MCP) and prints the Team -> Drive-folder table. Read-only — it never writes to n8n or Drive.
