# mn-team-onboard

Claude Code skill that **onboards a new team to the MN Service** (Meeting Notes) n8n pipeline from
minimal input — a **team tag** and a **parent Google Drive folder link** (Slack channel optional).
The assistant creates the required Drive subfolders, adds one routing entry to the pipeline config,
self-validates, and reports back — touching nothing else.

## What MN Service does (context)

MN Service routes every recorded meeting's **notes / transcript / video** to a team's Google Drive
folders and a Slack channel, based on a `[Tag]` in the calendar event title. Onboarding a team =
adding **one object** to the `teamsRaw` map in the Code node *"Config + Classification"*, where the
object **key** is matched (case-sensitive) against that `[Tag]`.

## How the skill works

```
input: teamTag + parentFolderUrl (+ optional slackChannel)
  │
  ├─ 1. verify parent folder (Drive) — notes.bot must have access
  │
  ├─ 2. create subfolders  ──►  POST n8n webhook  ──►  n8n creates, as notes.bot:
  │        (scripts/create-subfolders.sh)             • Videos
  │                                                    • Single Transcripts
  │        idempotent (search-before-create)           returns the two folder IDs
  │
  ├─ 3. build the one teamsRaw entry (key = exact tag, parent + subfolder IDs)
  │
  ├─ 4. STAGE: backup node code ► insert 1 entry ► diff must be pure insertion
  │            ► assert routes to its own folders (not defaults) ► else rollback + stop
  │
  ├─ 5. if Stage passed ► PROD: same steps, automatically (no human gate in between)
  │
  └─ 6. summary (deferred: first real meeting auto-creates the rotating Docs + Slack post)
```

**Key design points**
- **Secret never leaves the server.** The privileged "create folders as `notes.bot`" action runs only
  inside n8n, behind a token-protected webhook (`[NEW] Endpoint: MN Team Subfolders {MN Service}`,
  `POST /webhook/mn-team-subfolders`). No Google service-account key is stored on any laptop.
- **Autonomous Stage→Prod.** The gate between Stage and Prod is the **programmatic self-validation**
  (byte-level diff + assertions) plus rollback — not a human click. The operator only says
  "create the team".
- **Surgical & reversible.** Before every edit the node's `jsCode` is backed up locally (n8n keeps 0
  versions). The edit must add exactly one key and leave the other entries byte-identical; any failed
  check rolls back. Unrelated malformed nodes are never auto-fixed — the skill stops and reports.

## Prerequisites

- MCPs available to the assistant: **n8n** (read + partial node edit), **Google Drive** (read +
  metadata), and ideally **Outline** (wiki).
- `notes.bot@speedandfunction.com` has access to the n8n helper's Google Drive credential
  (already the standing MN Service requirement).
- `.env` (gitignored) with:
  ```
  MNB_SUBFOLDERS_WEBHOOK_URL=https://n8n.speedandfunction.com/webhook/mn-team-subfolders
  MNB_SUBFOLDERS_WEBHOOK_TOKEN=<secret>
  ```
  See `config/.env.example`.

## Usage

Invoke the skill and give it the two inputs, e.g.:

> create the MN team `AUT:MNB`, parent folder https://drive.google.com/drive/folders/XXXX

Or call the subfolder helper directly:

```bash
set -a && . ./.env && set +a
scripts/create-subfolders.sh <parentFolderId>
# → {"ok":true,"parentId":"...","videoFolderId":"...","singleTranscriptsFolderId":"..."}
```

## Files

| Path | Purpose |
|------|---------|
| `SKILL.md` | the skill definition (procedure, gates, assertions) |
| `scripts/create-subfolders.sh` | calls the n8n helper webhook |
| `reference/teamsRaw-entry.template.js` | the single config entry template |
| `config/.env.example` | env template (URL + token placeholder) |
| `backups/` | local node `jsCode` snapshots = rollback (gitignored) |

## Workflows / IDs

- Helper: `[NEW] Endpoint: MN Team Subfolders {MN Service}` — id `WNNKVG8CpNEybwh3`
- Config node *"Config + Classification"* — Stage wf `s3uBtg1Adp6II5GP` (node `5cb6741a-…`),
  Prod wf `SkEnOMQyotDXM05Z` (node `cd441c8d-…`)

## Status

Validated against ClickUp task `86ca0p92k`: `[AUT:MNB]` onboarded to Stage + Prod via the skill;
`[S&F:Website]` already present. Full end-to-end (rotating Docs + Slack delivery) verifies on the
first real `[AUT:MNB]` meeting.
