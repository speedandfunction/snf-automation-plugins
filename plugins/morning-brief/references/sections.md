# sections reference — morning-brief

Details for the SKILL.md steps: the status-verb→status mapping + safe apply (Step 2), the "what was done" detection (Step 3), the plate dedup (Step 4), blocker-reason derivation + the TeamMD resolver (Step 5), the real-Geekbot-mood read (Step 5), and the Geekbot payload (Step 8). Tool params are transcribed from the ClickUp MCP schemas, the Geekbot v1 API, and the team.md export.

## ClickUp query / write params (exact)
- **`clickup_filter_tasks`** — `assignees: string[]` of NUMERIC ids (resolve names/emails/"me" via `clickup_resolve_assignees(["<email>"])` first); `statuses: string[]` (lowercase status names as configured, e.g. `"in progress"`, `"in review"`, `"to do"`, `"blocked"`); `include_closed: bool` (MUST be `true` to see Closed tasks); `date_closed_from`/`date_closed_to` (pattern `YYYY-MM-DD` or `YYYY-MM-DD HH:MM`); `page` is **0-indexed** (paginate until short page); `order_by ∈ {id,created,updated,due_date}`; scoping `list_ids`/`folder_ids`/`space_ids` (`string[]`). There is **no** `assignee` singular and **no** `closed` boolean.
- **`clickup_update_task`** — the ONLY ClickUp write this skill makes. To change a status: `clickup_update_task(task_id="<id>", status="<status name>")`. The `status` value MUST be an actual status name configured on that task's list (case-insensitive match; an unknown status errors). Touch ONLY `status` here — never pass name/description/assignees/priority in this skill (that's `daily-call-tasks`). One call per task (no bulk endpoint) so a single failure is isolated.
- **`clickup_get_task(task_id)`** — read a task back after an update to confirm the new status, and (optionally) to read a Blocked task's CURRENT status label as a *suggestion* for the block reason. NOTE: there is **no** status-change/activity-history endpoint — the authoritative block reason is the user's Step-5 input, not a derived history (S9).
- **`clickup_get_task_comments(task_id)`** — each comment carries `user`, `date`, `resolved` (bool), `assignee` (the person it was sent TO, or `null`), `assigned_by`, `reply_count`. **Verified live** on task `86ca8brqx` (`resolved` + `assignee{id,username,email}` + `assigned_by` present). These are NOT in the MCP *input* schema, so re-confirm on first real run and **degrade** to a nameless "sent for review" if a comment lacks them. Used for reviewer resolution + as an OPTIONAL suggestion source for a block reason (the authoritative reason is the user's Step-5 input, S9).
- **Workspace statuses** — get the allowed status names for a task's list/space from `clickup_get_workspace_hierarchy` (list/folder/space status sets) and/or the task object's own `status` option list. This is the lookup table for Step 2's verb→status mapping; do NOT hardcode status names beyond the workspace's known terminal **Closed**.

## Step 2 — Status-management: verb→status mapping + safe apply

### Verb → real status mapping
The user types `<num>→<verb>` pairs. Resolve `<num>`→task id ONLY from FROZEN_MAP (Safe apply step 0), then map `<verb>` to a status NAME that actually exists on that task's list (synonyms, case-insensitive). The workspace's terminal status is **Closed** (there is NO "Done"), so map "done" → **Closed**:

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
0. **Freeze the number→id map (M4).** The 2A list MUST be pulled with `order_by="id"` (deterministic pagination) and, at render time, pinned into `FROZEN_MAP = { <num>: {task_id, name, list_id, old_status} }`. Steps 1–4 below resolve every `<num>` ONLY against `FROZEN_MAP` — never a fresh `clickup_filter_tasks` (an unordered re-query can reorder pages and re-point a number at a different task; the preview would then "confirm" the drift). If a re-pull is forced, re-render and ask the user to re-issue commands against the new numbers.
0b. **Parser guards (S11):** a `<num>` not in `FROZEN_MAP` (out-of-range) → REJECT + tell the user. Duplicate/conflicting arrows for one `<num>` (`3→done, 3→backlog`) → ASK which wins; never fire both. Resolve these BEFORE building the plan table.
1. Build the plan table from `FROZEN_MAP`: `№ | task | ticket-id | old-status → new-status`. Skip any row whose verb didn't map (it was asked, not assumed).
2. PREVIEW + confirm via `AskUserQuestion` (Apply / Edit / Cancel). Only the user's typed `<num>→<verb>` pairs ever become writes.
3. On Apply, loop tasks ONE AT A TIME. For each row, re-resolve `task_id` from `FROZEN_MAP[<num>]` and assert it equals the `ticket-id` shown in the previewed table before calling — mismatch → ABORT that row (map drifted), never fire it. Then `clickup_update_task(task_id, status="<name>")`. Catch per-task errors → push to `failed[]`; push successes to `applied[]`. Never roll back applied rows on a later failure; never retry-loop.
4. Re-read each updated task (`clickup_get_task`) or trust the returned object to confirm the landed status.
5. Auto-report `applied[]` / `failed[]`. Any task whose new status is **Closed** is recorded → it's UNION'd into Step 3B "what was done" (so a just-closed task shows even if a re-query lags).
- **Scheduled mode:** present the grouped list read-only; SKIP the question and the apply entirely (zero writes).

## Step 3 — "What was done": Closed-in-window ∪ transitions ∪ just-applied closes

### Closed in the window (exact)
`clickup_filter_tasks(assignees=[me], include_closed=true, date_closed_from=<computed bound>, date_closed_to=<now>)`.

**Compute the bound so a weekend is never dropped (weekend fix):**
- **No EXPLICIT period typed** (scheduled, or the manual "since last brief" default) → `date_closed_from = prior-snapshot date` (the gap since the last run). Do NOT let an implicit "yesterday" raise the floor — on a Monday that becomes Sunday and silently drops Saturday's closures.
- **An EXPLICIT period was typed** → `date_closed_from = asked-period-start` — honored LITERALLY, NO clamp. A narrower explicit period is respected for this query; a weekend/gap closure outside it is re-surfaced by the snapshot-diff via the task's current status (below), not by widening this floor.
- **First run / missing or corrupt snapshot (S2):** no prior-snapshot date → `date_closed_from = asked-period-start`; if NO period was asked, bound to the **last 24h**. **NEVER leave `date_closed_from` undefined** — an undefined bound makes `clickup_filter_tasks` pull the entire all-time closed history and mislabel it as "done".

`date_closed` fires for the terminal **Closed** status. The section label is "since `<date_closed_from>`" (the computed bound), never a hardcoded "yesterday". **UNION the ids the user just moved to Closed in Step 2C** — a just-applied close may not be reflected in this query yet, and surfacing it is the whole point ("did the work, forgot to update ClickUp").

### Snapshot-diff (In Progress / In Review transitions, ClickApp-free)
State file: `~/.claude/morning-brief/snapshot-<YYYY-MM-DD>.json` (date key in user TZ):
```json
{ "generated_at": "<ISO8601>", "tz": "<IANA>", "me": "<clickup id>",
  "tasks": { "<task_id>": { "status": "in progress", "name": "…", "url": "…", "ticket_id": "…" } } }
```
- **Capture set:** the user's NON-closed tasks (`clickup_filter_tasks(assignees=[me], include_closed=false)`, paginated). Write it at the END of every full run (Step 8).
- **Diff:** load the most recent snapshot whose date is **< today** (NOT today's fresh write — so a same-day re-run still diffs against the prior day). For each task:
  - in both, status changed → classify the NEW status: `→ in progress` = "worked on, not finished"; `→ in review` = "sent for review".
  - in prior snapshot but GONE from today's open set → closed or reassigned. **Reconcile:** id present in the closed-in-window result (or Step 2C's just-closed set) → "closed"; ELSE read the departed task's CURRENT status (`clickup_get_task`) — a terminal **Closed** status → "closed since your last brief"; otherwise "no longer on your plate" (do not claim done). This current-status read covers BOTH a closure that fell outside a narrow explicit window AND a **date-blind connector** (Step 0 probe, where the closed-in-window result is empty by construction) — so the day's real closures never vanish; footer-caveat that such closures are snapshot-inferred ("per status, not date-pinned").
  - new in today's set, not prior → a *new* task (belongs to "plate", not "done").
- **Window label:** "since `<date_closed_from>`" — the computed bound (the prior-snapshot gap-floor by default, or `asked-period-start` when an explicit period was typed; `asked-period-start`/last-24h on first run, S2); the prior snapshot may be older than yesterday after a weekend/skip; never hardcode "yesterday".
- **First run / no prior snapshot (or a corrupt/unparseable snapshot):** print "baseline captured — status changes will show from the next run", and still emit the closed-in-window result + Step 2C closes — but bind that closed-in-window query by `date_closed_from = asked-period-start` (or the last 24h if no period was asked), NEVER an undefined bound (S2).
- **Multi-hop within a day** (To-Do→In Progress→Review same day) → only endpoints are seen. Documented limitation; fine for a standup.
- **Retention:** keep the last ~14 snapshots; prune older.

### Reviewer resolution — "sent for review TO WHOM"
For each task classified `→ in review`: `clickup_get_task_comments(task_id)` → most recent comment with `resolved == false` AND `assignee != null`. `assignee` = the person it was sent to. Name from `assignee.username`; Slack mention via the TeamMD resolver (by `assignee.id` = ClickUp id, or `assignee.email`). No such comment → "sent for review" with no name (NEVER guess a reviewer).

## Step 4 — "On your plate" dedup: marker-first → Jaccard
The Step-1 call-items are deduped against the user's OPEN tasks so only genuinely un-ticketed items get the "⟂ not yet in ClickUp" flag.
1. **Marker-first.** Items previously ticketed via `daily-call-tasks` carry a hidden marker in the ClickUp task description:
   ```
   <!-- dca:<workspace_id>:<list_id>:<source_doc_id>:<call_date>:<action-key> -->
   ```
   This is the CANONICAL marker `daily-call-tasks` actually writes (5 components — no `assignee_id`; `call_date` = the call's start date so a recurring call reusing one Doc across weeks doesn't false-match). `action-key` hashes a STABLE locator (`source_doc_id` + the item's `section` + `item_anchor` — **NOT a line ordinal**, not prose). Enumerate the user's open tasks (`clickup_filter_tasks(include_closed=false)`), READ each description, and if a candidate call-item's `(source_doc_id, call_date, action-key)` matches a `dca:` marker on an open user-owned task → **already ticketed, drop it**. (`clickup_filter_tasks` can't filter description bodies — match by reading fetched descriptions, or `clickup_search` the marker string then intersect.)
2. **Jaccard fallback** (pre-existing human tasks, no marker): casefold + NFKC title tokens, drop stopwords, `|A∩B|/|A∪B| ≥ 0.70` against the same open set → treat as already-on-plate, drop the "not yet ticketed" flag.
3. Closed tasks and tasks not assigned to the user are NEVER matched → a resembling call item stays flagged as new.
This mirrors `daily-call-tasks`'s dedup so the two skills agree on "already ticketed".

## Step 5 — Block-reason: the reason is the USER's input (S9)
**The block reason comes from the USER — this flow ASKS for it (Step 5 asks blockers WITH a reason). Do NOT derive it from a "status-change note recorded WHEN it was blocked": no ClickUp tool returns status-change/activity history** — only `clickup_get_task` (the task's CURRENT status) and `clickup_get_task_comments` exist, so that history-derivation is impossible and must not be specified. The authoritative reason is exactly what the user types.
1. **Ask the user** why each Blocked task is blocked (the Step-5 `AskUserQuestion` already does this — `add <n>: <reason>`). Whatever they type is the reason.
2. **Optional suggestion only:** you MAY read `clickup_get_task(task_id)` (a current-status label like "Blocked: waiting on X") or `clickup_get_task_comments(task_id)` (the most recent UNRESOLVED comment) and OFFER it as a starting suggestion — but it is a hint, not the reason; the user's input wins.
3. If the user states no reason, render "blocked (reason not stated)". **Never invent a reason, and never reconstruct one from non-existent status-change history.**
The user's added reasons are display-only text (no ClickUp write).

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
Detected by a `*mail*`/`*gmail*` search-threads tool in Step 0, whose **exact name was captured there** (S13 — the connector id varies between sessions/installs; do NOT hardcode `mcp__claude_ai_Gmail__search_threads`, or invocation can fail while glob-detection "passed", silently dropping this optional section). **Read-only**, bounded:
- `<detected_search_threads_tool>(query="is:unread is:important in:inbox", pageSize=15, view="THREAD_VIEW_MINIMAL")` — call the tool name captured in Step 0 (e.g. `mcp__claude_ai_Gmail__search_threads`, but use whatever was detected). Minimal view returns each thread's subject + sender + snippet (enough to build the task; no `get_thread` needed). `is:important` ≈ Gmail's Priority-Inbox proxy. If the detected tool errors on invoke → skip the section with a hint, never fail the run.
- Each unread thread → one plate item **"reply to `<sender>` — `<subject>`"** — a TASK suggestion. The skill has `create_draft` access but NEVER uses it.
- Cap at `pageSize` (≤15); if more, append "+N more unread important".
- No Gmail tool → skip with a hint.

## Step 5 — Mood (the standup's real, multiple-choice options)
The mood question is **multiple-choice** (it has `answer_choices`); the posted answer MUST be one of those exact strings (S8). The known Geekbot mood options Andy configured — present THESE exact choices (emoji included) via `AskUserQuestion`. They MUST appear:
- 🚀 **Full power**
- 🙂 **Good**
- 😎 **Getting things done**
- 😔 **Low energy**
- 💊 **Out**

**No `✍️ custom` free-text option.** A custom string is by definition NOT in `answer_choices`, and the mood question is question 1 and mandatory — an out-of-set value risks Geekbot rejecting the whole report. So the user picks from the real options only; there is no "type your own mood".

**Reconcile against the live standup only if a Geekbot key is present** (the config could change): `GET https://api.geekbot.com/v1/standups/` (header `Authorization: <RAW_API_KEY>`) → the configured `geekbot.standup_id` (or the only standup) → the **mood question** (`text` ~ `/mood|how (are|do) you|how do you feel/i`, multiple-choice) → its `answer_choices`. If the live choices differ, present **those exact `answer_choices` strings**; otherwise use the five above. NEVER invent options.

**The Step-8 post value MUST be byte-for-byte ONE of the live `answer_choices` strings** — the verbatim text of the option the user picked (emoji included), never a paraphrase, a reworded label, or invented free-text. If the standup exposes the mood question as multiple-choice, post the selected option text **verbatim**. No key → still ask, post is preview-only; if skipped, send the question's allowed "no answer" (`—` if it is itself an `answer_choices` entry, else the closest neutral live choice), never a made-up mood.

## Step 8 — Geekbot post

### Sanitize untrusted text before it enters the payload (M1 — mandatory)
Every string that originates from ClickUp (task name, comment text, reviewer "sent for review to …" name) or from a call (action-item title/quote) is UNTRUSTED and is rendered into a Slack-visible Geekbot post. Slack interprets `<!channel>`, `<!here>`, `<@U…>`, `<#C…>`, `@channel`, `@here`, and `<…>` link/mention syntax. A teammate who can name/rename/comment on a shared task could plant `Fix <!channel> bug` → the post would fire a real broadcast/ping under the USER'S identity. So BEFORE any such string enters the payload (the link TEXT of a `[<name>](url)` task link, a block reason, a reviewer name, a call-item title):
1. **Neutralize Slack control glyphs in the untrusted text:** replace `<` → `&lt;`, `>` → `&gt;`, `&` → `&amp;` (Slack's own escape set). This makes `<!channel>` / `<@U…>` / `<#C…>` render as literal text, never a control sequence.
2. **Defang bare broadcast tokens:** rewrite `@channel`, `@here`, `@everyone` (case-insensitive, word-boundary) to a zero-width-broken form (e.g. `@​channel`) so they don't auto-link.
3. **Strip backticks** (or escape them) in untrusted text so an injected fence can't reshape the message.
Apply this ONLY to untrusted-origin substrings. The Markdown link wrapper `[…](url)`, the numbering, and resolver-emitted `<@SlackID>` mentions (built by the TeamMD resolver from the roster, NOT from task/comment text) are skill-generated and survive intact — they are the ONLY `<@…>` allowed in the payload. Net rule: **no `<!…>` / `<@…>` / `<#…>` / `@channel` / `@here` may reach the payload except a resolver-emitted `<@SlackID>`.** The Step-8 human skim can miss an embedded `<@U…>` in a long line, so this escaping (not the skim) is the real guard.

API base `https://api.geekbot.com/v1` (trailing slashes matter). Auth header **`Authorization: <RAW_API_KEY>`** (NO `Bearer`/`Token` prefix — a prefix 401s) + `Content-Type: application/json`. Key is MEMBER-scoped (per-user, paid plan); read from env `GEEKBOT_API_KEY` or `~/.claude/morning-brief/config.json` (`geekbot.api_key`) — NEVER hardcode. **Read `config.json` by JSON parse (`jq`/`python3 json`/`JSON.parse`), NEVER `source`/`eval` (S14 — sourcing a config whose `tz`/`teammd_path`/key value held `$(…)`/backticks would execute it; JSON-parsing closes that RCE).**
1. **Discover + fix the target deterministically (M6):** `GET /v1/standups/`. If config `geekbot.standup_id` is set, use it (verify it exists in the response). If unset and the response has **exactly one** standup → use it and **persist** its id to `~/.claude/morning-brief/config.json` → `geekbot.standup_id` (atomic write) so the target is stable across runs. If unset and **>1** standup → manual mode ASK which (show each standup's NAME + channel) and persist; scheduled/non-interactive → **REFUSE the post** (ambiguous target fails closed; never auto-pick "the first" — that lands the report in the wrong channel). Surface the resolved standup NAME + channel in the Step-8 preview. Each standup has integer `id` and `questions[]` with integer `id` + `text` (+ `answer_choices` for the mood question).
2. **Map** sections → questions by matching question text, in Andy's standup ORDER: the **mood / "how do you feel"** question → the chosen Mood (FIRST); "what have you done / since the previous report / yesterday" → What was done (numeric list); "what's on your plate / what will you do / today" → On your plate (numeric, ONLY the user's picked items); "blocking / blockers" → Blockers only; "questions to anyone / open questions" → Open questions. If they don't match, show the mapping and let the user confirm/edit before posting. Render each task name as a **clickable link** `[<name>](https://app.clickup.com/t/<id>)` (not a bare id — the raw id isn't searchable in ClickUp). NEVER expand a numeric list beyond what the user picked.
3. **Render the exact payload and PREVIEW it** (Hard Rule 4):
   ```json
   { "standup_id": <int>,
     "answers": { "<question_id>": { "text": "<section text>" }, "<question_id>": { "text": "…" } } }
   ```
   `answers` keys = question ids as STRINGS; ALL of the standup's questions must be present (empty-but-required → a short "—"). The mood question's answer = the chosen real option string (Step 5) — **byte-for-byte one of that question's live `answer_choices` strings, never a paraphrase or free-text** (S8).
4. **Confirm** via `AskUserQuestion` (Post / Skip). On Post → `POST /v1/reports/` with the header above. Handle `401` (bad/free-plan key) and `429` (back off) by reporting + keeping the paste-ready block; never retry-loop. Read-back optional via `GET /v1/reports/?standup_id=&user_id=`.
