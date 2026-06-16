---
name: mn-team-onboard
description: >
  Onboard a new team to the MN Service (Meeting Notes) n8n pipeline from minimal input —
  a team tag and a parent Google Drive folder link (Slack channel optional). The assistant
  creates the required Drive subfolders (as notes.bot, via an n8n webhook), adds one routing
  entry to the `teamsRaw` config, self-validates, and returns a result summary. Use when
  someone says "create the team / onboard team X to Meeting Notes / add a new MN team".
---

# MN Team Onboard

Onboard a new team to the **MN Service** meeting-notes pipeline. The pipeline routes each
recorded meeting's notes / transcript / video to a team's Google Drive folders and a Slack
channel, based on a `[Tag]` in the calendar event title.

## Input (minimal)

- **teamTag** (required) — the routing tag, e.g. `AUT:MNB`. This becomes the **object key**
  in `teamsRaw` and must equal the calendar `[Tag]` character-for-character (case-sensitive).
- **parentFolderUrl** (required) — link to the team's parent Drive folder.
- **slackChannel** (optional) — channel name without `#`. Empty is allowed (no team channel).

If either required input is missing, **stop and ask** — do not guess.

## What each piece touches (boundaries)

- The privileged "create subfolders as notes.bot" action happens **only** inside n8n via a
  token-protected webhook. The skill never holds the Google service credential.
- The only config change is **adding one entry** to `teamsRaw`. Nothing else in the node or
  the workflow is touched.

## Procedure

### 1. Resolve & verify the parent folder (read-only)
- Extract the folder ID from `parentFolderUrl`.
- `get_file_metadata` → confirm it is a `folder`.
- `get_file_permissions` → confirm **notes.bot@speedandfunction.com** is `owner` or has write
  (Editor/Content Manager). If notes.bot has only reader/none → **STOP and ask the human** to
  share the parent with notes.bot as Editor before continuing (the pipeline can't write otherwise).

### 2. Create the subfolders (idempotent)
- Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/create-subfolders.sh <parentId>` (loads `.env`). It calls the n8n helper webhook,
  which searches-before-creates, so re-running is safe and returns the same IDs.
- Capture `videoFolderId` and `singleTranscriptsFolderId` from the JSON response.
- Verify both via `get_file_metadata`: each must be a folder whose `parentId` == the parent.
- If the skill has **no** webhook access, fall back to the task's manual branch: **stop and ask**
  the human to create `Videos` + `Single Transcripts` under the parent and paste the two IDs.

### 3. Build the `teamsRaw` entry
Use `${CLAUDE_PLUGIN_ROOT}/reference/teamsRaw-entry.template.js`. Fill:
- key = exact `teamTag`; `name` = same; `promptTemplate` = `''` (or `defaultPromptUA` for UA teams)
- `meetingNotesFolderId` = `transcriptionFolderId` = parentId
- `videoFolderId`, `singleTranscriptsFolderId` = from step 2
- `meetingNotesDocId` = `transcriptDocId` = `''`
- `slackChannel` = given value or `''`

### 4. Apply to Stage, then auto-promote to Prod (autonomous — no mid-run human gate)
The operator's "create the team" instruction IS the approval. The gate between Stage and Prod is
the **programmatic self-validation below**, not a human click. Apply to **Stage first**, validate,
and only if every check passes, **immediately apply the same change to Prod** in the same run.

Targets — Code node **"Config + Classification"**:
- Stage: workflow `s3uBtg1Adp6II5GP`, node id `5cb6741a-68ba-49c9-bf6f-7a8cb3b4d45f`
- Prod:  workflow `SkEnOMQyotDXM05Z`, node id `cd441c8d-806b-40de-8e31-f7ef3acfa719`

For **each** workflow, in order (Stage, then Prod):
1. Fetch the node and **save its current `jsCode` to `backups/<env>-config-classification.js`**
   (n8n has 0 stored versions — this backup IS the rollback).
2. Assert `teamTag` is **not already a key**. If it exists → stop, report (this is an update, not an add).
3. Insert the one new entry with a targeted `n8n_update_partial_workflow` `patchNodeField`
   (find the `const teamsRaw = {\n  '<firstKey>': {` anchor, prepend the new block).
4. **Self-validation (the gate):**
   - Re-fetch the node, write to `backups/<env>-config-classification.after.js`, `diff` vs the backup:
     the diff MUST be a pure insertion of the one block — zero deletions, zero changes elsewhere.
   - Assert: exactly one key added (count +1); new key === exact `teamTag`; no required folder field
     empty or equal to a known default (video default `1HFIvTikZPywG2-aRah7kwgFnu30SqSCj`); video ≠
     singleTranscripts. Empty `slackChannel` allowed only when intentionally optional.
   - Confirm via Drive that the referenced folder IDs resolve and belong to the parent.
5. **On any failed check → restore the backup `jsCode` (rollback), STOP, and report.** Do NOT proceed
   to Prod if Stage failed.
6. **If the Stage checks all pass → proceed straight to Prod** (repeat 1-5). No human prompt in between.

**Blocked save (do not auto-fix unrelated nodes):** if a save is rejected because of a *pre-existing
malformed node elsewhere* in the workflow (the MCP validates the whole workflow), STOP and surface the
exact node + error. Do not silently modify nodes unrelated to the team-add — fixing them needs explicit
human approval.

### 5. Scope of self-validation
Validation confirms the routing table now maps `[Tag]` → the correct folders and the folders exist.
It does **not** prove end-to-end delivery — the two rotating Docs are only created on the first real
meeting, and Slack delivery can't be checked here. State that as an explicit deferred check.

### 6. Output summary
Report: team tag, parent, the two subfolder IDs, Slack channel (or "none"), which workflows were
edited, which self-validation signals passed, and the deferred "first real meeting" check.

## Hard rules
- The "create the team" instruction authorizes the scoped `teamsRaw` add on **Stage then Prod** and
  the subfolder creation — nothing else. Run it autonomously end-to-end (Stage → validate → Prod),
  gated only by the programmatic self-validation + rollback above.
- Never widen Drive permissions, never edit any node or field other than the single new `teamsRaw`
  entry, and never auto-fix unrelated malformed nodes — surface them for human approval instead.
- Always back up the node `jsCode` before editing and roll back on any failed check.
- Secrets (webhook token) live only in `.env` (gitignored) — never print them or commit them.

## Components
- `bash ${CLAUDE_PLUGIN_ROOT}/scripts/create-subfolders.sh` — calls the n8n helper webhook.
- `${CLAUDE_PLUGIN_ROOT}/reference/teamsRaw-entry.template.js` — the entry template.
- n8n helper workflow: `[NEW] Endpoint: MN Team Subfolders {MN Service}` (id `WNNKVG8CpNEybwh3`),
  webhook `POST /webhook/mn-team-subfolders`, body `{parentId}`, header `x-mnb-token`.
