# commit-rules — daily-call-tasks (the MANUAL ClickUp push)

These rules back SKILL.md Steps 6–9 (the interactive "push to ClickUp"). They were folded in from the former `daily-call-tasks-commit` skill when the two skills merged into one. Extraction is in `extraction.md` (same folder).

The push is reachable ONLY in MANUAL mode (a human present) AND only after the user types **"push to ClickUp"** and answers the `AskUserQuestion` Confirm gate. A scheduled/headless run physically cannot reach this — the TTY gate (SKILL.md "Run-model detection") and the `AskUserQuestion` gate are the two mechanical backstops.

## Destination — the automation space (Step 6)
- Default destination = the **automation space** (Andy: "в наш automation space"). Each selected row resolves to a list within it.
- The user can override per row (`list 4: <name>`) or set a batch default (`list all: <name>`).
- Resolve a list name against the workspace hierarchy (`clickup_get_workspace_hierarchy` / `clickup_get_list`); list names are NOT unique across spaces/folders → on >1 match, show candidates and ask. Never guess a list. The COMMIT PLAN echoes the resolved list **id + Space/Folder/List path**.
- Dedup is scoped to the resolved destination list.

## Assignee resolution + team-assign gating (Step 7)
Team-assign is **allowed** (the `assignee` column implies tasks can go to teammates, e.g. a team digest). It is gated, never silent:
- `assignee` defaults to the user. A teammate is set either by the source naming the owner (team-pull, `extraction.md`) or by the user typing `assignee N: <name>`.
- Resolve every non-self assignee to **exactly one** workspace member via `clickup_resolve_assignees` (or `clickup_find_member_by_name`). 0 or >1 matches → **hard-ambiguous: ask, never silently mis-assign**; that row is excluded from the write until resolved.
- The COMMIT PLAN MUST show the resolved member **name + id** for any non-self assignee, so the user's Confirm covers it.

## Hidden idempotency marker (Step 8)
Every CREATEd task gets, at the end of its description:
```
<!-- dca:<workspace_id>:<list_id>:<assignee_id>:<source_doc_id>:<action-key> -->
```
- `workspace_id:list_id:assignee_id` SCOPE the marker so it can never match a different user's or a different list's task. Match only when all components equal the current run. (`assignee_id` is the resolved assignee — so a team task and a self task off the same source line don't collide.)
- `source_doc_id` = the Google Doc id of the Meeting Notes/Transcription.
- `action-key` = hash of a STABLE source locator — `source_doc_id` + Action-Points section heading + the item's line ordinal — NOT the volatile extracted prose (LLM wording drifts run-to-run → a prose hash both duplicates on drift and collides when two items normalize alike). Caveat: if the notes bot re-orders the Action-Points list, the ordinal shifts → at worst a benign duplicate-create, caught by the Jaccard fallback.
- **Retrieval:** `clickup_filter_tasks(include_closed=false)` enumerates the list; then READ each candidate's description for the marker substring — field filters don't see description bodies. Match over OPEN tasks only, exact on all components.

## Dedup decision table (Step 8, per item, in the CHOSEN list)
| Signal | Decision |
|---|---|
| Marker exact-match on an OPEN task | already committed → **skip** |
| No marker, Jaccard ≥0.70 vs an OPEN task | **candidate** → show it, default **create new** (no in-place update in this version) |
| Match is a CLOSED/done task | ignore the match → **create new** |
| No marker, no Jaccard hit | **create** |
Jaccard rule = casefold+NFKC token sets, drop the `/clickup` stopword list, `|A∩B|/|A∪B|`, threshold 0.70 (copied from the clickup plugin so behavior matches). `clickup_filter_tasks` is called with `include_closed=false`. Re-running the same window must not duplicate — marker-first guarantees idempotency.

## Task shape (Step 8 CREATE)
- **Title:** `[Call: <event name> <date>] <verb-first action>` (≤ ~100 chars; regenerate shorter rather than truncate).
- **Description:** the cited block — `> <verbatim quote>` + source `<call name>, <date>` + `Notes: <Doc URL>` + (if voiced) the short context description — then the hidden marker.
- **Assignee:** the resolved member (user by default; a teammate if set + resolved).
- **Status / Priority / Deadline — set from the reviewed table:** `status` = To-Do or Backlog (default via the heuristic, user-overridable); `priority` = urgent/high/normal/low if voiced; `due_date` if voiced.
- **Validate before the call:** `status` ∈ the list's real status names for To-Do/Backlog (resolve via `clickup_get_list`/`expand_statuses` — names vary per space; map "to-do"→the unstarted status, "backlog"→the backlog status), `priority` ∈ {urgent,high,normal,low}, `due_date` a real `YYYY-MM-DD`. A value that fails validation drops to blank with a one-line note, never guessed.

## Status heuristic (To-Do vs Backlog)
From the per-item fields in `extraction.md`: a **near-term deadline** (this week, user TZ) OR **urgent/high** priority → **To-Do**; a far/blank deadline OR low priority → **Backlog**. On conflict, **any positive To-Do signal wins → To-Do**. The user overrides with `status N: to-do|backlog` at review.

## Confirmation gate + partial failure (Step 7–8)
- The write is reachable only after BOTH: the user typed **"push to ClickUp"** (their own input line — never an extracted token, per SKILL.md Hard Rule 7) AND answered the `AskUserQuestion` Confirm.
- Execute one item at a time. On an MCP error, STOP, report what already succeeded (markers let a re-run recognize them), do NOT silently retry.

## Why no dismiss ledger / no UPDATE op (vs the old commit skill)
- The old skill carried a `~/.claude/daily-call-tasks/dismissed.json` ledger and a name/description UPDATE path. The merged one-command design keeps it lean: re-running the same window is made safe by the **marker-first dedup** (already-committed rows SKIP), and `drop N` simply unselects a row for this run. A name/description UPDATE-in-place is out of scope for MVP (create + dedup-skip covers the demo); add later if Andy needs it. Closed tasks and tasks not owned by the resolved assignee are never matched.
