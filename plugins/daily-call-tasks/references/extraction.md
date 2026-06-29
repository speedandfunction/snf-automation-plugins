# Extraction reference — daily-call-tasks

Logic adapted (and trimmed) from Sasha Marchuk's read-only `find-call` skill. This skill targets a **whole-set digest rendered as tables** (scheduled = read-only; manual = tables + optional ClickUp push). It KEEPS the proven extraction primitives and DROPS find-call's interactive scoring/disambiguation.

This one skill replaces the former two (`daily-call-tasks` read-only digest + `daily-call-tasks-commit` interactive write). Extraction is here; the create/dedup/idempotency rules are in `commit-rules.md` in this same `references/` folder.

## Kept from find-call
- Calendar-as-index discovery of the user's events.
- "Meeting Resources" block parsing → Meeting Notes Doc export.
- Optional notetaker (Sembly) augment in parallel.
- Sonnet sub-agent per call to read notes/transcript and return cited action items.
- Anti-slop rules: cite everything; never invent; read-only; sonnet-only; never WebFetch Google URLs.

## Dropped (deliberately — no human in the loop / nothing to rank)
- Relevance **scoring** (Step 3 in find-call) — there is no query to score against; we take the whole attended set.
- **Disambiguation / AskUserQuestion** (find-call Step 4) — unattended runs cannot answer prompts.
- **Alias memory** (find-call Step 8) — stateless.
- `config_io.py` / `~/.claude/find-call/config.json` preference file — not needed; provider is auto-detected.

## Attended predicate (Step 2)
Keep event IFF:
- `organizer.self == true`, OR
- there is an `attendees[]` entry with `self == true` AND `responseStatus` ∈ {`accepted`, `tentative`}.

`self == true` is mandatory (else you mis-attribute other people's calls). `needsAction` (un-answered invite) and `declined` do NOT count as attended.

Exclude:
- non-meeting `eventType` — match **case-insensitively**: the connector returns CAPS (`WORKING_LOCATION`, `FOCUS_TIME`, `OUT_OF_OFFICE`), the CLI returns camelCase (`workingLocation`…).
- Re-narrow to the true `[start,end]` (in the resolved user TZ) after the ±1-day boundary padding.

## Meeting Resources regexes (Step 3)
Description is HTML — match links, do not parse as a tree. Strip query strings before use.
- Doc id:        `https://docs\.google\.com/document/d/([A-Za-z0-9_-]+)`
- Drive file id: `https://drive\.google\.com/file/d/([A-Za-z0-9_-]+)`
- Drive folder:  `https://drive\.google\.com/drive/folders/([A-Za-z0-9_-]+)`

**Capture each link together with its adjacent anchor text and select by that label** — bare ids alone cannot tell the Meeting Notes doc from the transcript/video doc. The notes-bot block typically labels links `Transcription` (sometimes `This Call` / `Project Calls`), `Meeting Notes`, `Video`, `Parent Folder`. Route only the **`Meeting Notes`**-labeled doc to extraction; pass a `Transcription`-labeled doc as the optional transcript; **skip `Video`** (binary; not transcribed here). **If the `Meeting Notes` doc is inaccessible (403/not-found) or absent, PROMOTE the `Transcription` doc (or a connected Sembly transcript) to be that call's extraction source** — notes-bot docs are often owned by the bot/team and 403 for the running account.

## Meeting Notes sections
Typical Markdown/Doc structure: `Topic:`, `Date:`, `Short Summary`, `Key Discussion Points`, `Action Points` (often per attendee), `Meeting Resources`. For action-item extraction the `Action Points` section keyed to `{user.name}` is the highest-signal source; quote it verbatim and cite the Doc URL + that section heading.

## Scope: whose items (self vs team-pull)
- **Default (scheduled, or a plain manual run):** extract items owned by `{user.name}`.
- **Team-pull (manual only):** when the user asks "pull everyone's / my team's tasks from this call", the orchestrator passes `PARTICIPANTS=<names>` to the sub-agent, which then ALSO extracts items owned by those named people — each with its real owner in the **assignee** field. Being in the room ≠ owning the item: only emit an owner the source actually names; otherwise the owner is `{user.name}`. Never invent an owner.

## Per-item fields (priority / deadline / assignee / description)
For EACH extracted action item, ALSO capture these **only if voiced** in the notes/transcript — leave a field blank otherwise, NEVER invent:
- **priority** → a ClickUp value `urgent` / `high` / `normal` / `low`. Set only when urgency was actually conveyed ("ASAP/today/critical" → urgent/high; "when you can/low-pri/nice-to-have" → low). Blank if not voiced.
- **deadline** → `YYYY-MM-DD`, only if a due date/timeframe was stated ("by Friday", "end of month", "before the 30th"). Resolve relative phrases against the **call date** (passed to the sub-agent as `<CALL_DATE>`), in the user TZ. Blank if none stated.
- **assignee** → the stated owner's name if the source names one (e.g. an `Action Points → <name>` heading, or "<name> will…"); else `{user.name}`. Never invent an owner. Resolved to a ClickUp member at push time (see `commit-rules.md`).
- **description** → a short (≤1–2 line) context summary from the surrounding discussion, enough that the task stands alone — NOT a long history/Acceptance-Criteria dump. Cite the source line. Blank if there's no context beyond the action title.

These become the Priority / Status / Deadline / Assignee / Description columns of THE TABLE (SKILL.md Step 5) + the To-Do/Backlog status heuristic. The status heuristic: a near-term deadline (this week) or urgent/high priority → `To-Do`; a far/blank deadline or low priority → `Backlog`. On conflict (e.g. near deadline but low priority, or urgent but far deadline), **any positive To-Do signal wins → `To-Do`**. The user can override every field at review (manual mode).

## THE TABLE (SKILL.md Step 5) — layout this reference backs
- **One table per meeting** (N meetings → N tables), heading above each = `<meeting name> · <date+time> · <participants>`.
- Columns in order: `№ | task name | priority | status | deadline | assignee | description` (assignee BEFORE description — description can be long, kept last).
- **Continuous numbering across ALL tables** in the run (table 2 starts where table 1 ended) so every task has a unique number the user can reference ("push 5, 6, 10").

## Provider fallback (Step 0)
Per source, try the present provider first, fall back to the other; only fail a source if every provider fails.
- Calendar: `mcp__*Google_Calendar*__list_events`  ⇄  `npx @googleworkspace/cli calendar events list`
- Docs:     **PRIMARY** the Drive connector `read_file_content(fileId)` — returns the Doc text directly (no export, no `mimeType`); the ONLY working path in a cloud routine.  ⇄  LOCAL-ONLY fallback `npx @googleworkspace/cli drive files export --params '{"fileId":"<id>","mimeType":"text/plain"}' --output ./.tmp/daily-call-tasks/<id>.txt` then `Read` (this writes a local scratch file — gitignored; the connector path writes nothing).
- Transcripts (optional): `mcp__sembly-ai__*` or any connected notetaker; skip silently if none.

In a **cloud routine** the claude.ai connectors are the available, pre-authed path (the local `npx` CLI is typically NOT authed there). Locally the CLI may be the faster path. Detect, don't assume.
