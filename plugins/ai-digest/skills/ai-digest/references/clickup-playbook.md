# ClickUp playbook — how the gather sub-agent reads the AUT space

All facts below were verified live against ClickUp space `90156104627` during the plan review. Follow them exactly — each one is a trap that silently produces wrong numbers in a public digest.

## Scope = the WHOLE space (not a sub-set of lists)

Space `90156104627` is literally named **"[AUT] Automation Department"** — the entire space IS the department. Its folders/lists:

- `[AUT] EBOS` → `2026 Q2`
- `[AUT] Operations` → `[AUT] Internal Tasks`, `[AUT] Infrastructure`, `[AUT] Capability Transfer`, `[AUT] Ideas`
- `[AUT] Internal Projects` → `[MNB] Rearchitecture`, `[MNB] Maintenance`, `[MAR] AI-Driven Website`, `[MAR] Marketing`, `[CLT] Cultural Indicators`, `[CLT] Connecting People Bot`, `[HR] HR Metrics`, `[HR] English AI Assistant`
- `[AUT] Client Projects` → `[TDE] Account Management`, `[TDE] E-Tool Maintenance & Support`

**RULE:** scope = `space_ids: ["90156104627"]`. The `[XXX]` list-prefix (`[AUT]/[MNB]/[MAR]/[CLT]/[HR]/[TDE]` + the `2026 Q2` quarterly list) is the **initiative grouping / de-dup key — NEVER a keep/drop filter.** `[MAR]`, `[HR]`, `[TDE]`, `2026 Q2` are AUT-OWNED initiatives, not other departments; narrowing to `[CLT]/[MNB]/[AUT]` would silently drop ~half the real work. Other real departments are *separate spaces*, not lists here.

## CLOSED pool (the "Closed this week" section)

```
clickup_filter_tasks(
  space_ids=["90156104627"],
  subtasks=true,                 # NOT false — see subtask trap
  include_closed=true,
  date_closed_from="<Mon of week, YYYY-MM-DD>",
  date_closed_to="<Sun of week, YYYY-MM-DD>",
  page=0,1,2... until empty       # paginate to exhaustion
)
```

Then, IN-SKILL (do not trust the query alone):

1. **`date_closed != null` post-filter (MANDATORY).** The `review` status has `type:"done"` but a **null `date_closed`**, and such tasks can appear inside a date-window query (e.g. task `86ca80z2p`). Drop every task whose `date_closed` is null OR falls outside the UTC week `[from,to)`. `date_closed` is an epoch-ms string — parse and compare in UTC.
2. **Subtask roll-up + de-dup.** `subtasks=true` returns parents AND children; `subtasks=false` *under-counts* (it drops genuinely-closed leaf tasks whose parent is still open — e.g. `86ca5urt4`, `86ca2eu4a`). So pull with `subtasks=true`, then: never emit a closed CHILD and its OPEN parent as two items (roll the child into the parent's initiative); de-dup by task id and by normalized title; **suppress recurring step leaves** matching `^Step \d+` (e.g. the "Step 1/2/3 — …" CPB check-in tasks).
3. **`date_closed` ≠ "shipped".** Many closures are housekeeping/admin/research ("Review all comments", "Sync all names", "Research X"). Keep them eligible, but the so-what + verb-lint (see `output-style.md`) decide whether a row reads as a shipment, a research result, or admin. Never auto-label a closed card "shipped".
4. **Reopen→reclose drift.** A task finished a prior week can be reopened and re-closed, giving it a fresh in-window `date_closed` so it looks new. There is no reliable reopen flag in `filter_tasks` (`date_updated > date_closed` only means "re-touched after closing"). When `date_created` is well before the week AND `date_updated > date_closed`, treat the item as a possible re-close: keep it but **flag it in the editor file** ("possible re-close — verify it's new") rather than presenting it to other departments as this week's accomplishment.

## IN-PROGRESS pool (the "In progress / discussed" section)

Open tasks **active this week** whose status is in an **active set** and NOT in the deny-list. Status names vary per list (`[CLT]` uses `review`, `[MNB]` uses `in review`, a literal `done` also exists), so resolve names from the live hierarchy/statuses, don't hard-code one spelling.

**"Active this week" — do NOT key on `date_updated` alone.** `clickup_filter_tasks` has no "status-changed-in-window" filter, and `date_updated` bumps on *any* edit (a tag, a watcher, a stray comment, a bulk op) — keying on it alone marks untouched work as "in progress". Qualify a task as active this week only if EITHER (a) its current status is in the active set AND it has a comment/note dated in the window, OR (b) the **notes narrative mentions it** (this section is notes-led — see SKILL Step 4). A bare `date_updated`-only hit is **demoted** to the editor file, not the reader copy. When uncertain, prefer the notes; ClickUp is corroboration here, not the lead.

- Active set (examples): `in progress`, `in review`, `review`, `ongoing`, `done` (open, not date_closed).
- Deny-list (exclude from In-progress): `to do`, `open`, `backlog`, `blocked`, `on hold`.

When in doubt, prefer the notes narrative for this section — ClickUp here is corroboration, not the lead.

## PRIORITIES pool (the "Priorities / next" section)

Open tasks with a `priority` set (urgent/high) OR a `due_date` in the near future, PLUS the next-steps/action-points from the notes. **Do NOT gate on `due_date`** — it is sparse/often null; a priority flag or a notes mention is enough. Expect a large candidate pool (~60+ open tasks) → this is why Step 5 ranks to a top-3.

## Pagination & limits

`clickup_filter_tasks` exposes a `page` param (0-indexed); a busy week can exceed one page. Always page until a page returns zero tasks before declaring a pool complete. There is no cursor; rely on `page`.

## Attribution

Each task has `assignees` (numeric user ids → names). Attribute per-task to its **initiative/list**, never person→team. Unassigned tasks are KEPT (the whole space is AUT) and credited to the initiative. Use `~/.claude/shared/identity.json` only to render names; never drop a task for missing identity.
