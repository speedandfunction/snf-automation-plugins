---
name: mn-team-links
user-invocable: true
description: >
  Resolve an MN Service (Meeting Notes) team to its Google Drive transcript folder
  link, so the assistant can answer "where are team X's transcripts / notes?" from a
  live link-base instead of searching the whole Drive. It reads the team list straight
  from the n8n MN Service config (the single source of truth, via the connected n8n MCP)
  and prints a compact Team → Drive-folder table. Use when someone asks for a team's
  transcript/notes folder, the link to a team's recordings, or a list of all MN teams.
---

# MN Team Links

A read-only "link-base" for the **MN Service** meeting-notes pipeline. MN Service routes
every recorded meeting's notes / transcript / video into a team's Google Drive folders
based on a `[Tag]` in the calendar event title. The mapping of **team → folders** lives,
hardcoded, in one place: the `teamsRaw` object inside the n8n Code node
**"Config + Classification"**. This skill READS that object live and projects each team's
folder IDs into Drive URLs. It never searches Drive, never edits n8n, and never stores its
own copy of the team list or any secret.

## When to use

- "Where are the transcripts / notes for `<team>`?"
- "Give me the Drive folder link for `<team>`."
- "List all MN teams and their folders."

## How it works (uses the connected n8n MCP — no API key)

The skill relies on the n8n connection the user's assistant **already has** (n8n MCP). No
credential is stored in this repo.

1. **Fetch the node via n8n MCP.** Call `n8n_get_workflow` for workflow `SkEnOMQyotDXM05Z`
   (mode `full`) and take the `parameters.jsCode` of the node **"Config + Classification"**.
2. **Pipe that jsCode into the parser.** Write it to a temp file (or pipe via stdin) and run:
   ```bash
   node ${CLAUDE_PLUGIN_ROOT}/scripts/team-links.mjs "<query>" < config-node.js
   ```
   The parser extracts `teamsRaw`, turns folder IDs into Drive URLs, filters by the query,
   and prints a small Markdown table.
3. **Answer from the table.** Lead with the parent transcript folder link of the matched team.

Why pipe through the script instead of eyeballing the object: the parser deterministically
extracts all entries (35+), handles aliases / special-character keys / empty fields, and
never invents a URL — so the answer is consistent and not a hallucinated link.

> Token note: the MCP fetch pulls the workflow into context once. That is heavier than a
> bare key+REST call, but it needs no stored secret and is still far cheaper than searching
> the whole Drive — which is the problem this skill removes.

## Usage

```bash
# MCP path (default): the assistant pipes the node jsCode in
node ${CLAUDE_PLUGIN_ROOT}/scripts/team-links.mjs                 < config-node.js   # every team
node ${CLAUDE_PLUGIN_ROOT}/scripts/team-links.mjs "two labs"      < config-node.js   # filter by tag or name
node ${CLAUDE_PLUGIN_ROOT}/scripts/team-links.mjs --json AUT      < config-node.js   # machine-readable JSON
# (or pass a saved file explicitly)
node ${CLAUDE_PLUGIN_ROOT}/scripts/team-links.mjs "AUT:MNB" --jscode-file /tmp/config-node.js
```

Example output:

```
AUT:MNB → https://drive.google.com/drive/folders/1ZN4AElF0JKJpw_wP6zctymKwUR06O6S4

| Team (tag) | Parent transcript folder | Single transcripts | Slack |
|---|---|---|---|
| AUT:MNB | …/1ZN4AElF0JKJpw_wP6zctymKwUR06O6S4 | …/1Nur2RnHU6cqxg9ZVgJeHCPvHYykZxNBV | — |

1 team(s).
```

## What the columns mean

- **Parent transcript folder** — the team's main folder (`transcriptionFolderId`, which
  in the live config equals `meetingNotesFolderId`). This is the default answer to
  "where are team X's transcripts/notes?" — the same folder the bot links in Slack.
- **Single transcripts** — the per-call transcripts subfolder (`singleTranscriptsFolderId`).
  About half the teams leave this empty; the cell shows `—` then, and the parent folder is
  the answer.
- **Slack** — the team's channel, context only.

## Resolution rules

- Query matches a team's **tag (object key)** OR its **name**, case-insensitive substring,
  so any reasonable phrasing works.
- Aliases that point at the same folder (e.g. `AUT` / `Automation` / `Aut`, or a
  `… | Int` pair) are kept as **separate rows** — the skill mirrors n8n exactly and never
  merges or drops entries.
- A folder field that does not look like a Drive ID (e.g. a Slack name mis-pasted into a
  folder field in n8n) is shown verbatim as `(invalid id: …)` instead of a fake URL. This
  is presentation only — the n8n data is never altered.

## Boundaries

- **Read-only.** The skill only reads (one MCP `n8n_get_workflow`). It never writes to n8n,
  Drive, or anywhere else. To ADD or change a team, use the companion skill
  **`mn-team-onboard`**, which is the writer for the same `teamsRaw` config.
- **No stored secret.** The normal path uses the user's connected n8n MCP. There is no API
  key in this repo.
- **Single source of truth.** No cached team list — the answer is whatever `teamsRaw`
  currently holds, so a team onboarded a minute ago shows up immediately.

## Optional: headless / automation fallback

For a non-interactive context with **no MCP** (e.g. a cron job), the CLI can fetch the
workflow itself over the n8n REST API if `N8N_API_KEY` is set in `.env` (see
`config/.env.example`). This is opt-in only and not needed for normal assistant use — the
MCP path above stores nothing.

## Components

- `scripts/team-links.mjs` — CLI: parse piped node jsCode (or optional REST fetch), print
  the link table.
- `scripts/lib/parse-teams.mjs` — extracts `teamsRaw` and builds the link rows.
- `scripts/test-parse.mjs` + `scripts/fixtures/sample-node.js` — offline parser test
  (`node ${CLAUDE_PLUGIN_ROOT}/scripts/test-parse.mjs`), runs without n8n access.

## Related

- `mn-team-onboard` — the companion writer skill (adds a team to the same `teamsRaw`).
- Source node: Prod workflow `SkEnOMQyotDXM05Z`, node `cd441c8d-806b-40de-8e31-f7ef3acfa719`
  ("Config + Classification"); Stage twin node `5cb6741a-68ba-49c9-bf6f-7a8cb3b4d45f`.
