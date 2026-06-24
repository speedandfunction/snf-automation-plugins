# sections reference — morning-brief

Details for the SKILL.md steps: the status-verb→status mapping + safe apply (Step 2), the "what was done" detection (Step 3), the plate dedup (Step 4), blocker-reason derivation + the TeamMD resolver (Step 5), the real-Geekbot-mood read (Step 5), and the Geekbot payload (Step 8). Tool params are transcribed from the ClickUp MCP schemas, the Geekbot v1 API, and the team.md export.

## ClickUp query / write params (exact)
- **`clickup_filter_tasks`** — `assignees: string[]` of NUMERIC ids (resolve names/emails/"me" via `clickup_resolve_assignees(["<email>"])` first); `statuses: string[]` (lowercase status names as configured, e.g. `"in progress"`, `"in review"`, `"to do"`, `"blocked"`); `include_closed: bool` (MUST be `true` to see Closed tasks); `date_closed_from`/`date_closed_to` (pattern `YYYY-MM-DD` or `YYYY-MM-DD HH:MM`); `page` is **0-indexed** (paginate until short page); `order_by ∈ {id,created,updated,due_date}`; scoping `list_ids`/`folder_ids`/`space_ids` (`string[]`). There is **no** `assignee` singular and **no** `closed` boolean.
- **`clickup_update_task`** — the ONLY ClickUp write this skill makes. To change a status: `clickup_update_task(task_id="<id>", status="<status name>")`. The `status` value MUST be an actual status name configured on that task's list (case-insensitive match; an unknown status errors). Touch ONLY `status` here — never pass name/description/assignees/priority in this skill (that's `daily-call-tasks`). One call per task (no bulk endpoint) so a single failure is isolated.
- **`clickup_get_task(task_id)`** — read a task back after an update to confirm the new status, and to read a Blocked task's current status text / status-change note for the block reason.
- **`clickup_get_task_comments(task_id)`** — each comment carries `user`, `date`, `resolved` (bool), `assignee` (the person it was sent TO, or `null`), `assigned_by`, `reply_count`. **Verified live** on task `86ca8brqx` (`resolved` + `assignee{id,username,email}` + `assigned_by` present). These are NOT in the MCP *input* schema, so re-confirm on first real run and **degrade** to a nameless "sent for review" if a comment lacks them. Used for reviewer resolution + as a fallback source of a block reason.
- **Workspace statuses** — get the allowed status names for a task's list/space from `clickup_get_workspace_hierarchy` (list/folder/space status sets) and/or the task object's own `status` option list. This is the lookup table for Step 2's verb→status mapping; do NOT hardcode status names beyond the workspace's known terminal **Closed**.

## Step 2 — Status-management: verb→status mapping + safe apply

### Verb → real status mapping
The user types `<num>→<verb>` pairs. Resolve `<num>`→task id from the numbered list, then map `<verb>` to a status NAME that actually exists on that task's list (synonyms, case-insensitive). The workspace's terminal status is **Closed** (there is NO "Done"), so map "done" → **Closed**:

| user verb (synonyms) | maps to status |
|---|---|
| `done`, `closed`, `complete`, `finished` | **Closed** (workspace terminal) |
| `on hold`, `hold`, `paused`, `parked` | an `on hold` status if the list has one; else ASK |
| `backlog`, `later` | `backlog` if present, else `to do` |
| `to do`, `todo` | `to do` |
| `in progress`, `wip`, `started`, `doing` | `in progress` |
| `review`, `in review`, `for review` | `in review` |
| `blocked`, `block` | `blocked` |

**If a verb has no matching status on that list → ASK the user which real status they mean (offer the list's actual statuses). NEVER guess or invent a status name.** A status that doesn't exist on the list will error on write anyway.

### Safe apply
1. Build the plan table: `№ | task | ticket-id | old-status → new-status`. Skip any row whose verb didn't map (it was asked, not assumed).
2. PREVIEW + confirm via `AskUserQuestion` (Apply / Edit / Cancel). Only the user's typed `<num>→<verb>` pairs ever become writes.
3. On Apply, loop tasks ONE AT A TIME: `clickup_update_task(task_id, status="<name>")`. Catch per-task errors → push to `failed[]`; push successes to `applied[]`. Never roll back applied rows on a later failure; never retry-loop.
4. Re-read each updated task (`clickup_get_task`) or trust the returned object to confirm the landed status.
5. Auto-report `applied[]` / `failed[]`. Any task whose new status is **Closed** is recorded → it's UNION'd into Step 3B "what was done" (so a just-closed task shows even if a re-query lags).
- **Scheduled mode:** present the grouped list read-only; SKIP the question and the apply entirely (zero writes).

## Step 3 — "What was done": Closed-in-window ∪ transitions ∪ just-applied closes

### Closed in the window (exact)
`clickup_filter_tasks(assignees=[me], include_closed=true, date_closed_from=<prior-snapshot date>, date_closed_to=<now>)`. **The `date_closed` window MUST span the SAME gap the snapshot-diff covers** — bound it by the prior-snapshot date (matching the "since `<prior-snapshot date>`" label), NOT the narrow done-window. Otherwise a task closed during a weekend/gap is missing here and the snapshot-diff mislabels a genuinely-done task as "no longer on your plate". `date_closed` fires for the terminal **Closed** status. **UNION the ids the user just moved to Closed in Step 2C** — a just-applied close may not be reflected in this query yet, and surfacing it is the whole point ("did the work, forgot to update ClickUp").

### Snapshot-diff (In Progress / In Review transitions, ClickApp-free)
State file: `~/.claude/morning-brief/snapshot-<YYYY-MM-DD>.json` (date key in user TZ):
```json
{ "generated_at": "<ISO8601>", "tz": "<IANA>", "me": "<clickup id>",
  "tasks": { "<task_id>": { "status": "in progress", "name": "…", "url": "…", "ticket_id": "…" } } }
```
- **Capture set:** the user's NON-closed tasks (`clickup_filter_tasks(assignees=[me], include_closed=false)`, paginated). Write it at the END of every full run (Step 8).
- **Diff:** load the most recent snapshot whose date is **< today** (NOT today's fresh write — so a same-day re-run still diffs against the prior day). For each task:
  - in both, status changed → classify the NEW status: `→ in progress` = "worked on, not finished"; `→ in review` = "sent for review".
  - in prior snapshot but GONE from today's open set → closed or reassigned. **Reconcile against the closed-in-window result (and Step 2C's just-closed set):** id present there → "closed"; else "no longer on your plate" (do not claim done).
  - new in today's set, not prior → a *new* task (belongs to "plate", not "done").
- **Window label:** "since `<prior-snapshot date>`" — the prior snapshot may be older than yesterday after a weekend/skip; never hardcode "yesterday".
- **First run / no prior snapshot:** print "baseline captured — status changes will show from the next run", still emit the closed-in-window result + Step 2C closes.
- **Multi-hop within a day** (To-Do→In Progress→Review same day) → only endpoints are seen. Documented limitation; fine for a standup.
- **Retention:** keep the last ~14 snapshots; prune older.

### Reviewer resolution — "sent for review TO WHOM"
For each task classified `→ in review`: `clickup_get_task_comments(task_id)` → most recent comment with `resolved == false` AND `assignee != null`. `assignee` = the person it was sent to. Name from `assignee.username`; Slack mention via the TeamMD resolver (by `assignee.id` = ClickUp id, or `assignee.email`). No such comment → "sent for review" with no name (NEVER guess a reviewer).

## Step 4 — "On your plate" dedup: marker-first → Jaccard
The Step-1 call-items are deduped against the user's OPEN tasks so only genuinely un-ticketed items get the "⟂ not yet in ClickUp" flag.
1. **Marker-first.** Items previously ticketed via `daily-call-tasks` carry a hidden marker in the ClickUp task description:
   ```
   <!-- dca:<workspace_id>:<list_id>:<assignee_id>:<source_doc_id>:<action-key> -->
   ```
   `action-key` hashes a STABLE locator (`source_doc_id` + Action-Points heading + line ordinal), not prose. Enumerate the user's open tasks (`clickup_filter_tasks(include_closed=false)`), READ each description, and if a candidate's `<source_doc_id>:<action-key>` matches a marker on an open user-owned task → **already ticketed, drop it**. (`clickup_filter_tasks` can't filter description bodies — match by reading fetched descriptions, or `clickup_search` the marker string then intersect.)
2. **Jaccard fallback** (pre-existing human tasks, no marker): casefold + NFKC title tokens, drop stopwords, `|A∩B|/|A∪B| ≥ 0.70` against the same open set → treat as already-on-plate, drop the "not yet ticketed" flag.
3. Closed tasks and tasks not assigned to the user are NEVER matched → a resembling call item stays flagged as new.
This mirrors `daily-call-tasks`'s dedup so the two skills agree on "already ticketed".

## Step 5 — Block-reason derivation
For each Blocked task, the reason usually lives in the status or the comment recorded WHEN it was blocked:
1. Read `clickup_get_task(task_id)` — many workspaces store a free-text note ON the status change ("Blocked: waiting on X") or a `status` whose label encodes the reason. Use that if present.
2. Else `clickup_get_task_comments(task_id)` — find the comment nearest the block transition (or the most recent unresolved one mentioning the block) and quote a short reason.
3. Else render "blocked (no reason recorded)". **Never invent a reason.**
Then let the user ADD extra reasons (display-only text, no ClickUp write): `add <n>: <reason>`.

## Step 5/8 — TeamMD resolver
Resolve the roster from the FIRST that exists — config `teammd_path` → `~/Work/team.md` (capital W) → a synced `team.md` under `~/.claude/**` or a `Speed and Function` folder (Andy's TeamMD skill's synced copy — prefer it when present). Two GFM pipe-table sections — `## Full Members` and `## External / Multi-Channel Guests` — **union both**. Columns, in order:
```
Full Name | Slack Username | Display Name | Slack ID | Work Email | ClickUp ID
```
Parsing: split on `|`, trim; a literal em-dash `—` (U+2014) = null. Skip the header + `|---|` separator rows.
Join keys (reliability order): **Slack ID** (present on every row — the value to emit), **Work Email** (unique, some null), **ClickUp ID** (unique, ~half null), **Name** (collision-prone — never resolve on first-name alone).
Resolvers:
- `clickup_id_to_record(id) → {name, slack_id, email}` — for reviewer resolution (Step 3) from a comment's `assignee.id`.
- `email_to_slack_id(email) → slack_id` — for reviewer / `assignee.email`.
- `name_to_slack_id(name) → [candidates]` — returns a LIST; **>1 hit ⇒ ambiguous, do NOT auto-pick** (ask or keep plain name).
**Mention format:** emit `<@SlackID>` (angle bracket + `@` + the raw `U…` id, e.g. `<@U01ABCDEF>`) — never the username or display name. Known ambiguities to respect: duplicate display names exist (two "Lana Mamukova", two "Misha") — first-name-only resolution is forbidden. **Fail closed (Hard Rule 4):** an unresolved/ambiguous name in text destined for a Geekbot post → keep the plain name, WARN, never emit a broken `@`.

## Step 6 — Emails (Gmail connector)
Detected by a `mcp__*Gmail*__*` tool in Step 0. **Read-only**, bounded:
- `mcp__claude_ai_Gmail__search_threads(query="is:unread is:important in:inbox", pageSize=15, view="THREAD_VIEW_MINIMAL")` — minimal view returns each thread's subject + sender + snippet (enough to build the task; no `get_thread` needed). `is:important` ≈ Gmail's Priority-Inbox proxy.
- Each unread thread → one plate item **"reply to `<sender>` — `<subject>`"** — a TASK suggestion. The skill has `create_draft` access but NEVER uses it.
- Cap at `pageSize` (≤15); if more, append "+N more unread important".
- No Gmail tool → skip with a hint.

## Step 5 — Mood: read the REAL Geekbot options
Andy configured several mood options in Geekbot; the skill must present THOSE, not invented defaults.
1. `GET https://api.geekbot.com/v1/standups/` (header `Authorization: <RAW_API_KEY>`) → array of standups; pick the configured `geekbot.standup_id` (or the only standup).
2. Find the standup's **mood question** — the one whose `text` matches `/mood|how (are|do) you|how do you feel/i`. Geekbot mood questions are a **multiple-choice** type; read the choices from the question's `answer_choices` (a.k.a. `choices` / `answers`) array — these are Andy's actual options.
3. Present those exact strings to the user via `AskUserQuestion` (+ a "skip" path). Send the chosen string back as that question's answer in Step 8.
4. **No key / mood question not found** → degrade: free-text mood prompt, post is preview-only; if found-but-skipped, send the question's allowed "no answer" (or `—`), never a made-up mood.

## Step 8 — Geekbot post
API base `https://api.geekbot.com/v1` (trailing slashes matter). Auth header **`Authorization: <RAW_API_KEY>`** (NO `Bearer`/`Token` prefix — a prefix 401s) + `Content-Type: application/json`. Key is MEMBER-scoped (per-user, paid plan); read from env `GEEKBOT_API_KEY` or `~/.claude/morning-brief/config.json` (`geekbot.api_key`) — NEVER hardcode.
1. **Discover:** `GET /v1/standups/` → pick `geekbot.standup_id` (or the only one). Each standup has integer `id` and `questions[]` with integer `id` + `text` (+ `answer_choices` for the mood question).
2. **Map** sections → questions by matching question text: "what did you do / yesterday" → What was done; "what will you do / today / plan" → On your plate; "blockers / blocked" → Blockers; the **mood** question → the chosen Mood; a catch-all / "anything else" → Open questions. If they don't match, show the mapping and let the user confirm/edit before posting. Keep each task's ClickUp ticket id in the text.
3. **Render the exact payload and PREVIEW it** (Hard Rule 4):
   ```json
   { "standup_id": <int>,
     "answers": { "<question_id>": { "text": "<section text>" }, "<question_id>": { "text": "…" } } }
   ```
   `answers` keys = question ids as STRINGS; ALL of the standup's questions must be present (empty-but-required → a short "—"). The mood question's answer = the chosen real option string (Step 5).
4. **Confirm** via `AskUserQuestion` (Post / Skip). On Post → `POST /v1/reports/` with the header above. Handle `401` (bad/free-plan key) and `429` (back off) by reporting + keeping the paste-ready block; never retry-loop. Read-back optional via `GET /v1/reports/?standup_id=&user_id=`.
