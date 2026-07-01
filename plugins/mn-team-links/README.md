# mn-team-links

A Claude Code skill that turns the **MN Service** (Meeting Notes) team list into a
**link-base**: ask for a team and get its Google Drive transcript folder link, instead of
searching the whole Drive. It reads the team → folder mapping **live** from the n8n config
the pipeline runs on — through the **n8n MCP the assistant is already connected to**, so
there is no API key to store anywhere.

## Why this exists

MN Service routes each recorded meeting's **notes / transcript / video** into a team's
Google Drive folders, based on a `[Tag]` in the calendar event title. That team → folder
mapping is hardcoded in **one** place — the `teamsRaw` object inside the n8n Code node
**"Config + Classification"**. Finding a team's transcript folder used to mean searching
Drive (slow, token-heavy). This skill reads `teamsRaw` directly and prints the link.

## How it works

```
ask: "where are <team>'s transcripts?"
  │
  ├─ 1. n8n MCP: n8n_get_workflow(SkEnOMQyotDXM05Z, full)         ← uses the assistant's
  │        └─ take node "Config + Classification" → parameters.jsCode    existing connection
  │
  ├─ 2. pipe that jsCode into the parser:
  │        node scripts/team-links.mjs "<query>" < config-node.js
  │        ├─ extract the `teamsRaw` object
  │        └─ project folder IDs → Drive URLs, filter by query
  │
  └─ 3. prints a small Team → folder table → the assistant answers from it
```

**Design points**

- **No stored secret.** The normal path uses the n8n MCP the assistant already has. There
  is no API key in this repo. (An optional REST fallback exists for headless/cron use — see
  below — but it is opt-in and not needed for assistant use.)
- **Live, not cached.** There is no copy of the team list here. The single source of truth
  is the n8n node; this skill only reads it. A team added via the companion
  `mn-team-onboard` skill appears immediately.
- **Read-only.** One `n8n_get_workflow` read. It never writes to n8n, Drive, or anything.
- **Faithful to n8n.** Every key/alias in `teamsRaw` is shown as-is. Aliases that point at
  the same folder (`AUT` / `Automation` / `Aut`, `… | Int` pairs, etc.) are kept as
  separate rows — nothing is merged, renamed, or dropped.
- **No fake links.** A folder field that is not a Drive-shaped ID (e.g. a Slack name
  mis-pasted into a folder field in n8n) is shown as `(invalid id: …)`, never a fabricated
  URL. Presentation only — the n8n data is untouched.

> The MCP fetch pulls the workflow into context once per question. That is a bit heavier
> than a bare key+REST call, but it stores no secret and is still far cheaper than the
> Drive-wide search this skill replaces.

## What you get back

| Column | Meaning |
|---|---|
| **Parent transcript folder** | the team's main folder (`transcriptionFolderId`, = `meetingNotesFolderId` in the live config). The default answer — same folder the bot links in Slack. |
| **Single transcripts** | the per-call transcripts subfolder (`singleTranscriptsFolderId`); empty for ~half the teams → shown as `—`. |
| **Slack** | the team's channel, context only. |

## Prerequisites

- The assistant has the **n8n MCP connected** (read access to the MN Service workflow).
- **Node.js 18+** to run the parser (no npm dependencies).

## Usage

The assistant fetches the node via MCP and pipes its jsCode into the CLI:

```bash
node scripts/team-links.mjs                 < config-node.js   # every team
node scripts/team-links.mjs "two labs"      < config-node.js   # filter by tag or name
node scripts/team-links.mjs --json AUT:MNB  < config-node.js   # machine-readable JSON
node scripts/team-links.mjs "AUT:MNB" --jscode-file /tmp/config-node.js
```

Or just invoke the skill conversationally: *"where are the AUT:MNB transcripts?"*

## Optional: headless / automation fallback (no MCP)

For a non-interactive context with no MCP (e.g. a cron job), the CLI can fetch the workflow
itself over the n8n REST API if you set `N8N_API_KEY` in `.env` (see `config/.env.example`).
Opt-in only; not needed for normal assistant use.

```bash
cp config/.env.example .env   # then set N8N_API_KEY
node scripts/team-links.mjs "AUT:MNB"
```

## Test (offline, no n8n needed)

```bash
node scripts/test-parse.mjs
```

Runs the parser against `scripts/fixtures/sample-node.js` — a trimmed excerpt of the real
node code that exercises aliases, empty fields, a non-Drive-ID value, a shared-drive root,
and a special-character key.

## Files

| Path | Purpose |
|------|---------|
| `skills/mn-team-links/SKILL.md` | the skill (when/how to use, rules, boundaries) |
| `scripts/team-links.mjs` | CLI: parse piped node jsCode (or optional REST fetch), print the table |
| `scripts/lib/parse-teams.mjs` | extract `teamsRaw`, build link rows |
| `scripts/test-parse.mjs` | offline parser test |
| `scripts/fixtures/sample-node.js` | fixture node code for the test |
| `config/.env.example` | env template for the optional REST fallback only |

## Source of truth / IDs

- Node **"Config + Classification"** — Prod workflow `SkEnOMQyotDXM05Z`
  (node `cd441c8d-806b-40de-8e31-f7ef3acfa719`), Stage twin node
  `5cb6741a-68ba-49c9-bf6f-7a8cb3b4d45f`.
- Companion writer skill: **`mn-team-onboard`** (adds a team to the same `teamsRaw`).

## Scope

Reading and linking only. Onboarding/editing teams is the job of `mn-team-onboard`. A full
MNB dashboard (Meeting Notes Bot 2.0) is out of scope for this skill.
