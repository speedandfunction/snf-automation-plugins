---
name: ai-digest
description: Drafts a weekly cross-department "AI Automation digest" for the Speed & Function automation team — top-3 Closed-this-week / In-progress / Priorities, so other departments can see what the team is doing. Notes-led: the team's own meeting-notes are the primary narrative; ClickUp supplies the dated "what closed" signal and the priority backlog. Every line is cited; the output is a PRINT-ONLY draft a human edits and the lead publishes — it never auto-posts. Read-only against Google Drive + ClickUp. Makes NO "verified/corroborated" claims (the author of the note, the ticket, and the call are the same person — the citation, not a confidence badge, is the honesty). Use when the user wants to draft the weekly AI-Automation department digest, a cross-dept progress update, or "what did the automation team ship/work on this week". Geekbot is an OPTIONAL 3rd source (enrich-only, OFF unless a key is configured). Prints the draft only — no fuzzy call↔task join, no delivery (v2).
disable-model-invocation: false
user-invocable: false
---

# /ai-digest — Weekly AI-Automation Digest (notes + ClickUp + optional Geekbot, print-only draft)

Draft the automation department's **weekly cross-department digest**: three short sections — **Closed this week**, **In progress / discussed**, **Priorities / next** — each capped to a top few, every line **cited**, written so a reader in another department understands the *outcome*, not the worklog. The output is a **draft a human rewrites**; the lead publishes it. This skill is **read-only** and **never auto-posts**.

> **Provenance.** The skill scaffold (config-driven sources, preflight, parallel sonnet fan-out, two-output emit, read-only + "never print credentials" discipline) is adapted from Sasha Marchuk's MIT-licensed `log-time` skill (github.com/SashaMarchuk/claude-plugins) and the sibling `daily-call-tasks` skill in this marketplace. The digest brain (buckets, ClickUp playbook, ranking, so-what translation, anti-worklog rules) is original.

## What this is NOT (v0 scope — decided by review, deferred to v2)

- **No "verified" / "corroborated" / 🟢 tier and no confidence badges.** On every row the person who closed the ticket, wrote the note, and spoke on the call is the *same person* — there is no independent witness, so a "verified" label would overclaim to other departments. The **citation is the honesty**. Say "Closed this week (per ClickUp)", never "Verified/Shipped".
- **Geekbot = OPTIONAL ENRICH-ONLY 3rd source (OFF unless a key is configured).** Geekbot carries the per-person *forward-looking* intent/blockers that notes+ClickUp lack. But it is the WEAKEST evidence (self-reported — same person as the note + ticket), so it **never originates a reader theme and never creates a "Closed" line**. It only (a) corroborates an existing notes/ClickUp line (adds a `(per Geekbot, <date>)` citation) and (b) feeds a clearly-labelled **"From standups (unverified)"** lane with blockers / forward intent / off-ticket work. Without a key in `~/.geekbot/env`, the digest runs identically on notes+ClickUp. Full mechanics: `references/geekbot-playbook.md`.
- **Calls = the Meeting-Notes Docs, not raw transcripts.** The skill reads the auto-generated **Meeting-Notes Doc** for each AUT call (the dept's own call output), not the raw transcript and not Geekbot. A call with no notes section is invisible to it — acceptable because the notes bot covers AUT calls, but say so if a known call is missing.
- **No fuzzy call↔task join.** Only an exact ClickUp task-id/URL appearing in a note links the two; otherwise the note and the task stand on their own citations. (Fuzzy join = v2.)
- **No delivery, no ticket writes, no auto-post.** Print-only. (Slack/Doc delivery = v2.)
- **No lexicographic ranking determinism.** v0 ranks by an LLM top-N with a shown rationale + a stable sort key. (Deterministic scoring = v2.)

## Invocation & flags (parse first)

| Flag | Meaning | Default |
|---|---|---|
| `--week=<when>` | Target ISO week: `last` (default), `this`, `YYYY-Www` (e.g. `2026-W25`), or any `YYYY-MM-DD` (the ISO week containing that date). **On a bare interactive run (no `--week`) the skill CONFIRMS the period first** (Step 2); pass `--week` to skip that prompt | `last` (confirmed interactively) |
| `--out=<path>` | Where to write the editor/audit file: a directory or a full path. `home` = the legacy `~/.claude/ai-digest/runs/<week>/` location | the **current working directory** (`./ai-digest-<YYYY-Www>.md`) |
| `--dry-run` / `--print-only` | Print the draft only (also the default behavior) | on |
| `--tz=<IANA>` | Timezone for the human-readable week label only; the data window is computed in **UTC** (see Step 2) | resolved per Step 0 |
| `--max-subagents=N` | Cap on parallel gather sub-agents | `4` |
| `--yes` / `--non-interactive` | Skip BOTH interactive checkpoints (the first-run setup OFFER in Step 1b and the period confirm in Step 2) and run straight through on whatever is configured. Set this for any headless / `claude -p` / scheduled invocation | off |
| `--setup` / `--onboard` | **Interactive** mode: walk the human through configuring the optional Geekbot source LOCALLY (the key never leaves their machine). See `## Mode: --setup`. | off |

## Hard rules (NON-NEGOTIABLE)

1. **Cite everything.** Every digest line anchors to a real artifact: a ClickUp task URL, or a Meeting-Notes Doc URL + `### *Date:*` section. **No citation → it does not go in the digest.**
2. **Never invent.** Only emit work that appears in ClickUp (a real task) or the notes (a real section). A thin week stays thin — never manufacture accomplishments to fill a top-3.
3. **No verification vocabulary.** Never write "verified", "corroborated", "confirmed shipped", or a confidence badge. The bucket is **"Closed this week (per ClickUp)"**. so-what describes the outcome; the citation backs it.
4. **Read-only.** Zero writes to ClickUp / Drive / Slack / Gmail / anywhere. The draft TELLS the human what to do; it does not act.
5. **Anti-worklog.** A digest that reads like a list of closed Jira tickets has failed. Lead with the **notes narrative** (decisions, outcomes, who-it-affects); ClickUp dates and backs it. Run the so-what + verb-lint rules in `references/output-style.md` on every reader-facing line.
6. **Sonnet sub-agents only** for the gather pass (Step 3). Never opus, never haiku.
7. **Never WebFetch a Google URL** — they need auth WebFetch can't supply. Use the Drive connector / the read tool.
8. **Always emit something** (heartbeat). A green run with an empty digest must print the empty-state (Step 6), never nothing.
9. **Never `find`/`grep -r`/walk the filesystem to locate skill files.** The references sit next to this SKILL.md (Step 0). A disk-wide search hangs for ages and is never needed — `Read` the path directly or fall back to the inline rules. Sub-agents are handed their rules inline; they never look for a file.

## Step 0 — Config, identity, providers

- **Locate this skill's own files (do this WITHOUT searching the disk).** The reference files live next to this SKILL.md under `references/`. Resolve the skill directory as `${CLAUDE_PLUGIN_ROOT}/skills/ai-digest` when that env var is set (installed as a plugin), otherwise the directory containing this SKILL.md (project-skill case). **NEVER run `find` / `grep -r` / a filesystem walk to locate skill files** — that scans the whole disk and hangs. If a reference path doesn't resolve in one direct `Read`, fall back to the rules summarized inline in this SKILL.md and proceed; do not search.
- **Targets config (optional, has built-in defaults):** read `~/.claude/ai-digest/config.md` if present (free-form; overrides the defaults below). Defaults for the Speed & Function automation department:
  - ClickUp space: **`90156104627`** ("[AUT] Automation Department" — the *whole space* is the dept; see `references/clickup-playbook.md`).
  - Notes folder: Google Drive **`1Rzb1nVmvlKf_enEkWB2q6tcixDgiC0sx`** (the AUT "Automation" notes folder; rolling Meeting-Notes Docs).
  - **Geekbot (OPTIONAL):** ON only if `~/.geekbot/env` exists with `GEEKBOT_API_KEY` AND the config pins a `standup_id` + question→bucket map. If absent → Geekbot is **OFF** and the digest runs on notes+ClickUp unchanged (never HALT). Full mechanics + the one-time coverage test: `references/geekbot-playbook.md`.
- **Identity / roster (optional):** read `~/.claude/shared/identity.json` if present (the same file `/clickup` and `/gevent` write; read-only — never write it) for `user`, `teammates[]`. Used only for attribution labelling; never HALT if absent.
- **Providers (detect from the session tool list; prefer-then-fallback — get the data):**
  - ClickUp: the connected ClickUp MCP (`mcp__clickup__clickup_filter_tasks`, `clickup_get_task`, `clickup_get_workspace_hierarchy`).
  - Notes: a Google Drive MCP/connector (`mcp__*Google_Drive*__*`) to list + read the notes folder's Docs.
  - Geekbot: the REST API via `curl` (Bash), key read **as data** (`grep '^GEEKBOT_API_KEY=' ~/.geekbot/env | cut -d= -f2-`) inside the same Bash call — **never `source`d** (a value with `$()`/backtick would execute → RCE), never exported, never in argv (see `references/geekbot-playbook.md`).
  - If a custom source in the config needs a credential (an env var / file), load it silently and **never print, echo, or log the secret value**.

## Step 1 — PREFLIGHT (probe each source, do not gather yet)

Probe each source with the smallest possible read and print a table `[OK | BROKEN | OFF] <source> — <note>`:
- **ClickUp** — two probes. **(a) reach** — one `clickup_get_workspace_hierarchy` on the space (confirms reach + lists/statuses); on auth-fail, surface the re-auth hint and STOP that source (don't silently proceed). **(b) `date_closed` capability (MANDATORY — connectors differ).** Reach is NOT enough: make ONE tiny `clickup_filter_tasks(space_ids=[<space>], include_closed=true, subtasks=true, date_closed_from=<7d ago>, date_closed_to=<today>, page=0)` and inspect the rows. **Decide date-blind ONLY from a NON-EMPTY result — a zero-row probe is NOT date-blind:**
  - If the probe returns **≥1 task** AND those tasks have `date_closed` **absent / always-null** → the connector is **date-blind** → print `[OK date-blind] ClickUp — no usable date_closed; Closed pool uses the status+notes fallback (approximate window)` and set the Closed pool to that fallback (see `references/clickup-playbook.md` → "CLOSED pool — date-blind fallback").
  - If the probe returns **ZERO rows** → you CANNOT conclude date-blind (an empty result is indistinguishable from a genuinely quiet week with no closures). Re-probe ONCE over a **wider 90-day window**; if that ALSO returns zero rows, **assume `date_closed` is present** (the date-window Closed query is safe even when it legitimately returns nothing) and print `[OK] ClickUp — date_closed present (probe window empty; assuming date-capable)`. Never downgrade a quiet week to the lossy fallback.
  - On a probe **ERROR** (not an empty result) → retry the probe ONCE; if it still errors, mark ClickUp **`[BROKEN]`** (an error is NOT date-blind) and STOP that source — never silently treat an error as date-blind.
  - Otherwise (≥1 row WITH a real `date_closed`) → print `[OK] ClickUp — date_closed present`. (This is the exact split that bit a tester: the connector that *reached* the space exposed no date fields, while the one with a native `date_closed` filter couldn't see the space — never assume `date_closed` works just because ClickUp is reachable.)
- **Notes** — reachability is NOT enough; you MUST confirm there is **parseable content for the target week**. List the notes folder (403 trap = the running account isn't shared into the notes-bot folder → say so), then open the rolling Meeting-Notes Doc and confirm **≥1 `### *Date:*` section falls inside the week window**. Try BOTH header spellings `### *Date:*` and `### Date:` (the header drifted once before) and warn if only the non-asterisk form matches. If the folder is reachable but **no in-week date-section parses**, mark Notes **DEGRADED** (not OK) — do not silently treat it as present.
- **Geekbot** — if no `~/.geekbot/env` file, an **empty** `GEEKBOT_API_KEY` value, or no pinned `standup_id` → `[OFF] Geekbot — not configured (run /ai-digest --setup to enable it locally)` and skip it entirely (this is the normal, silent state today). If a key IS present: read it **as data** (`grep '^GEEKBOT_API_KEY=' ~/.geekbot/env | cut -d= -f2-` — **never `source`**, see `references/geekbot-playbook.md`) and run one leak-proof `curl … /v1/standups/` to confirm it authenticates (HTTP 200) and the pinned standup resolves. **OFF vs BROKEN (loud-fail):** a *configured* key that returns 401/empty/error is **BROKEN, not OFF** — print `[BROKEN] ⚠ Geekbot configured but auth failed (HTTP <code>)` and carry that warning into the digest **footer** ("ran WITHOUT Geekbot — rotate the key in ~/.geekbot/env"); never silently downgrade a BROKEN key to OFF (that hides a dead-key source drop). Either way proceed on notes+ClickUp; never HALT.

Geekbot being OFF is normal and never blocks. If **both ClickUp and Notes** are BROKEN, print the preflight table and stop with a one-line reason — never emit a confident-but-empty digest. If Notes is BROKEN/DEGRADED but ClickUp is OK, proceed **ClickUp-only** and the coverage footer MUST say so explicitly ("notes unavailable this week — ClickUp-only; this digest is a task list, not the full narrative") — this is the guard against silently shipping a closed-ticket worklog that reads as "the team did little". If ClickUp preflighted **`[OK date-blind]`** (no usable `date_closed`), the Closed pool runs in the status+notes fallback and the digest footer MUST say: "Closed-this-week is approximate — this ClickUp connector exposes no close-date, so closures are dated by their meeting-note mention, not a `date_closed` window; closures with no note may be missing."

## Step 1b — OFFER (first-run / setup checkpoint, interactive)

This is the checkpoint a first-time user needs: it surfaces what's configured and **offers to walk them through connecting anything missing — ClickUp, the Drive notes connector, Geekbot — before** committing to the long gather. It GUIDES, it never FORCES: a user who only wants the notes+ClickUp draft can always proceed.

**Interactivity rule (used here AND in Step 2 — define once).** Treat the run as **non-interactive** (skip the checkpoint, never prompt) whenever ANY of: `--yes`/`--non-interactive` is set; the session is **headless** — invoked via `claude -p`, a non-TTY/piped stdin, a hook, or a scheduled/cron job; or `AskUserQuestion` cannot be presented for any reason. **When you are unsure whether the session is interactive, default to NON-interactive** — never risk hanging an unattended run; the only cost is that a `--week`-less headless run uses `last` (the documented default). Only fire the checkpoint when you can positively present `AskUserQuestion` to a human.

**When Step 1b fires.** Only on an interactive run (per the rule above) AND when there is actually something to offer. **Skip straight to Step 2** when **nothing needs offering** — ClickUp `[OK]` (not date-blind) AND Notes `[OK]` AND Geekbot is `[OK]` **or `[OFF]`**. A bare Geekbot `[OFF]` (no key configured) is the **normal** state and **never on its own** triggers the offer — Geekbot discovery happens via the post-print `--setup` hint (end of skill), not here; this keeps a today-normal user (ClickUp+Notes OK, Geekbot OFF) on the smooth, no-prompt path. The offer fires ONLY when a source needs attention: ClickUp or Notes is `BROKEN`/`DEGRADED`/`[OK date-blind]`, or Geekbot is `[BROKEN]` (a configured key that auth-failed).

**Otherwise, fire the offer:**
1. Print the Step-1 status table (`[OK | OK date-blind | BROKEN | DEGRADED | OFF] <source> — <note>` for ClickUp, Notes, Geekbot).
2. Ask ONE `AskUserQuestion` titled **"Sources & setup"**, stem: *"Preflight done (status above). The gather runs up to `--max-subagents` parallel sub-agents and can take ~10–20 min. How do you want to proceed?"* — so this single prompt also doubles as the long-run confirmation. Offer only the options that apply:
   - **Run now (on what's connected)** — proceed to Step 2 on whatever preflighted OK. ALWAYS offered; the right choice for a notes+ClickUp-only draft. Picking it is identical to today's behavior.
   - **Connect a data source first** — offered when ClickUp or Notes is BROKEN/DEGRADED/date-blind. Walk the connector guidance below, then **re-run Step 1's probes** and re-ask.
   - **Set up Geekbot first** — offered when Geekbot is `[BROKEN]` (a dead configured key), OR when the offer is already open for ClickUp/Notes and Geekbot is `[OFF]` (so a user who's here anyway can opt in) — **never** forced by a bare `[OFF]` alone. Run `## Mode: --setup`, then return here, re-probe, and continue.
   - **Cancel** — stop without gathering.

**Connector setup guidance** (the skill walks any machine through connecting its sources — it never connects them itself; it tells the human exactly what to do, then re-probes):
- **ClickUp** — if no ClickUp MCP tool is present in the session, or it's present but auth-fails: the user needs a connected, authenticated ClickUp MCP server (Claude Code: add the ClickUp MCP and complete its OAuth). If a ClickUp MCP IS present but **date-blind** (reach OK, no `date_closed`): explain it can't date-pin closures; if they have access to a ClickUp connector that exposes `date_closed` AND can see space `90156104627`, switch to it — otherwise the digest uses the approximate status+notes fallback (fine, just flagged in the footer).
- **Notes (Google Drive)** — a 403/empty on the notes folder means the running Google account isn't shared into the notes-bot Drive folder (`1Rzb…`): tell them to share that folder **read-only** with the account this session uses. If no Drive connector is present at all, tell them to connect one. Then re-probe.
- **Geekbot** — OFF/BROKEN → route into `## Mode: --setup` (it creates `~/.geekbot/env`; the user pastes the key **into that file**, never into the chat).
After any guided fix, **re-run the Step 1 probes** and re-show the table — never proceed on stale status.

## Step 2 — SCOPE (the week window, in UTC)

**Confirm the period (interactive, bare-run only).** If `--week` was NOT explicitly passed AND the run is **interactive** (per the single interactivity rule in Step 1b — headless / `--yes` / non-TTY / unsure ⇒ non-interactive ⇒ skip this prompt): FIRST resolve what `last` means (the most recently completed Mon–Sun, as ISO `YYYY-Www` with concrete from/to dates) and CONFIRM it before any gathering, via one `AskUserQuestion` titled **"Reporting week"** that **shows the concrete dates** for each choice: (a) **Last week** [default] — e.g. `2026-W25 (Mon 2026-06-16 → Sun 2026-06-22 UTC)`; (b) **This week (in progress)** — its dates; (c) **A specific week** — let them give an ISO week `YYYY-Www` or any `YYYY-MM-DD`. Resolve their pick and proceed. If `--week` WAS passed, or the run is non-interactive (per the Step 1b rule) → SKIP this prompt and resolve silently (scriptable/cron path). Option (c) takes a second interactive turn (the free-text week) — that's fine on this already-interactive path. Showing the dates is the point — it answers "which week did it even run?".

Resolve the **ISO week** from `--week` (default `last` = the most recently completed Mon–Sun). Compute the window as a **UTC** `[from, to)` (Mon 00:00 UTC → next Mon 00:00 UTC). Both sources are sliced on this same UTC boundary so an item closed/discussed at a week edge can't half-belong. Print the resolved week + UTC window + (for the human label only) the `--tz`/config timezone. Per the closures: the notes Docs render their `### *Date:*` headers in **UTC**, so UTC is the correct join clock.

## Step 3 — GATHER (parallel sonnet sub-agents, artifacts only)

First, the orchestrator (you) reads `references/clickup-playbook.md` and `references/output-style.md` ONCE from the skill dir resolved in Step 0 (one direct `Read` each — never search for them), and `references/geekbot-playbook.md` too ONLY if Geekbot is ON (Step 1). Then launch the source sub-agents **in one message** (parallel) — ClickUp + Notes always, **plus Geekbot only if it preflighted OK** — **pasting the concrete rules inline into each sub-agent's prompt**. **Do NOT mention any file path in a sub-agent's prompt** — paste the rules themselves, never a pointer to a file. Every sub-agent prompt MUST begin with: *"Your rules are COMPLETE in this prompt. Do NOT open, Read, `find`, `grep`, or search for any file — there is nothing else to read. Work only from this prompt + the MCP tools."* (A fresh sub-agent doesn't know the skill path; the moment it's told a fuller version lives in a file, it may try to locate that file and trigger a disk-wide `find` that hangs.) Cap at `--max-subagents`. Each sub-agent writes its findings to a run artifact and returns a compact summary. **Heartbeat (don't run silent for ~20 min):** the moment you dispatch them, print one line — `[gather] launched: ClickUp + Notes (+ Geekbot) — up to ~10–20 min` — then print **each sub-agent's compact summary as it returns** (not only after all finish), so a slow gather shows progress instead of dead air (this is the second half of Andy's "it ran 20 min and told me nothing").

- **ClickUp sub-agent** — paste these rules into its prompt (no file path). **Branch first on the Step-1 `date_closed` probe** (the orchestrator MUST paste the matching branch inline — the sub-agent can't read the playbook):
  - **If ClickUp preflighted `[OK date-blind]`** (reach OK but no usable `date_closed`): build the **Closed** pool from status+notes, NOT a date window. Call `clickup_filter_tasks(space_ids=["90156104627"], include_closed=true, subtasks=true)` with **NO `date_closed_from/to`** (paginate to 0); keep only tasks whose **current status is a terminal Closed/Done status** (resolve the real status name from the hierarchy — `review` is NOT closed); admit a Closed-status task to **Closed** ONLY if this week's notes mention it (by task id/URL, or initiative-prefix + normalized-title) — **notes-mention ONLY** (do NOT use "an in-week comment" as an admission signal: `filter_tasks` returns no comments and reading them needs the `get_task` this branch forbids). Then **roll up closed child subtasks to their parent and de-dup** (never a closed child + its open parent as two; suppress `^Step \d+` recurring leaves) — exactly as the date-window branch. Label every such line `(per ClickUp status, notes-dated)`; **SKIP the reopen-drift `get_task` carve-out** entirely (`date_created`/`date_updated` are also absent on a date-blind connector — don't guess). Build In-progress + Priorities as in the date-window branch (both are notes-led and need no `date_closed`).
  - **Otherwise (`date_closed` present):** one `clickup_filter_tasks` call per pool over the whole space `90156104627` with `subtasks=true` (paginate via `page` only until a page returns 0; if a page ERRORS, stop and surface it — an error is not "0 tasks"; backstop at 20 pages). **The `filter_tasks` response already contains `date_closed`, `status`, `assignees`, `list`, `url` for every task — do NOT call `get_task` across the open pools** (that turns ~60 tasks into hundreds of calls — the original hang). The ONLY allowed `get_task` is a per-row carve-out on the **Closed pool** (a handful of tasks) to fetch `date_created`/`date_updated` for the reopen-drift check; skip it and drop that check rather than guessing. Then in-prompt: **post-filter `date_closed != null` and inside the UTC week** (the `review` status is done-type with a null `date_closed` and leaks into a date-window query); roll up closed child subtasks to their parent and **de-dup** (never a closed child + its open parent as two; suppress `^Step \d+` recurring leaves).
  In BOTH branches produce three raw pools — **Closed**, **In-progress** (open + moved this week, status in the active set, minus the deny-list), **Priorities** (open + priority/due) — and tag each task with its initiative prefix (`[AUT]/[MNB]/[MAR]/[CLT]/[HR]/[TDE]/Q2`), assignee, list, and URL. **Bounded retry (anti silent-hang):** if a `filter_tasks` page times out or errors, retry it **at most once**; if it still fails, stop that pool, mark it **partial**, and surface the gap loudly in the footer ("ClickUp coverage partial — a list/page failed") — never serially re-wait the same call many times (that's the silent-20-min trap Andy hit). Respect `--max-subagents`. Target ≤ ~6 tool calls total.
- **Notes sub-agent** — read the **full body** of the AUT notes folder's rolling Meeting-Notes Doc(s) (NOT the Drive content-snippet — it strips the load-bearing `*` in `### *Date:*`). These rolling Docs can be very large (300k+ chars); the sub-agent slices to the week's `### *Date:*` sections and **returns only those sections' extracted items — never the full doc body** (so a big Doc can't blow the main context). Extract, with Doc-URL + section citations: decisions, outcomes, owners, **next-steps / action points**, and **non-ticketed work** (research, firefighting, anything discussed that may never become a ticket — this is what keeps the digest a narrative, not a ticket dump).
- **Geekbot sub-agent (ONLY if Geekbot preflighted OK)** — paste the `references/geekbot-playbook.md` rules inline (no file path). In short: read the key as data (`grep '^GEEKBOT_API_KEY=' ~/.geekbot/env | cut -d= -f2-` — **never `source`**) then `curl` with the key via stdin `-K -` (**never argv**, no `set -x`); ≤3 bounded calls to `/v1/standups/` + `/v1/reports/?standup_id=<pinned>&after=&before=&limit=100` (UNIX-seconds window, omit `user_id` = all members, no per-person loop, error ≠ empty); post-filter by `timestamp` to the UTC week; bucket each answer by the **pinned question→bucket map** (PAST/FUTURE/BLOCKER/EXCLUDE — never re-infer tense). Compute `coverage = reporters/roster`; if `< 0.6` → editor-file only + a loud footer. RETURN aggregate only: (a) per-initiative **enrichment hits** (a Geekbot answer whose initiative-prefix also appears in this week's notes/ClickUp → "corroborates: <outcome>" + date, to thicken that line), and (b) a **"From standups (unverified)"** list of blockers / forward intent / off-ticket items with NO notes/ClickUp line, plain-language, **no names**, `(per Geekbot, <date>)` + reporter count. Raw per-person answers go to the editor file only. Never originate a "Closed" item.

## Step 4 — SYNTHESIZE (build the three buckets, notes-led)

Merge the artifacts into three sections. **De-dup** across sources and weeks by **initiative prefix** + normalized title; an exact ClickUp task-id/URL found in a note attaches that note's narrative to the task (the only allowed join). Each item carries ≥1 citation.

- **Closed this week (per ClickUp)** — closed tasks, grouped by initiative. Each line: the outcome (notes narrative if the task is mentioned, else the task name rewritten as an outcome) + so-what + the task URL. Apply the **verb-lint** (`references/output-style.md`): never say "shipped/delivered" on a Research/Investigate/Review/Sync/housekeeping card — `date_closed` means "the card was closed", not "a product shipped". Classify ship vs research vs admin in the so-what.
- **In progress / discussed** — notes-led narrative of what the team worked on + ClickUp in-progress items. This is the section that makes it a story, not a worklog.
- **Priorities / next** — ClickUp open + priority/due + the notes' next-steps/action-points. Do **not** gate on `due_date` (it's sparse).

**Geekbot integration (only if it ran) — enrich, never originate:**
- **Enrichment hits** thicken an EXISTING notes/ClickUp line for the same initiative (and add a `(per Geekbot, <date>)` citation alongside the existing one). Geekbot **never adds a second line** for an initiative notes/ClickUp already carry, and **never creates a "Closed this week" item** (Closed = ClickUp `date_closed` only).
- The **"From standups (unverified)"** items (blockers / forward intent / off-ticket work with no notes/ClickUp line) go to a clearly-labelled lane that feeds **Priorities/In-progress** as cited Geekbot lines — but an **achievement verb** ("advanced/progressed/shipped") on any Geekbot-touched line requires **≥2 distinct reporters AND** a corroborating notes/ClickUp line; otherwise use a literal verb ("noted/flagged") or demote it to the editor file.
- If Geekbot coverage was `< 0.6` (sparse week) it contributes **editor-file only** — no reader/quarantine lines — and the footer says so.

## Step 5 — RANK (top-3 per section + also-ran)

For each section, pick the **top 3** by significance for an outside reader — cross-dept impact, a real outcome/shipment, a named artifact, breadth — with a **one-line rationale per pick** (shown in the editor file). Recurring/admin items rank low. Ties keep both; thin sections under-fill (3 is a ceiling, never a quota — never pad). Everything not in the top-3 goes to the **also-ran** list in the editor file, so the human can see and re-promote what the model cut.

## Step 6 — EMIT (two outputs, print-only)

Before emitting, run two **gates** (don't just assert them — perform them and report the counts in the editor file):
- **verb-lint gate** — scan every reader-facing line for ship-vocab (`shipped/delivered/launched/released`); for each hit, check the underlying card type per `references/output-style.md`; rewrite any on a Research/Investigate/Spike/Review/Sync/Evaluate/Audit/housekeeping card. Log `verb-lint: N lines checked, M rewritten`. A card whose name doesn't match the keyword list but is clearly housekeeping (e.g. "Close out … leftovers") is still demoted from ship-vocab — judge by the work, not just the keyword.
- **consistency check** — every reader-copy line must have a matching citation in the editor file; assert the reader top-3 ⊆ the editor pools and that no reader line is uncited. Report `cite-check: K reader lines, K cited`.
- **Geekbot reader-line gate (only if Geekbot ran)** — for every reader line carrying a `(per Geekbot)` citation, fail-closed if it contains: a roster name/handle/`^Name:`/first-person (live-roster lint), OR an untranslated jargon token — CamelCase / ALL-CAPS / snake_case / an error-code (e.g. `Pyannote`, `Payload`, `Temporal`, `goal_strength`), not just `VEXA` — run the so-what TRANSLATE rule (`references/output-style.md`) on it or demote it to the editor file. Also enforce the ≥2-reporter rule for achievement verbs (Step 4). Log `geekbot-gate: N lines, M demoted`.

Then print **both** outputs. **Write the editor/audit file to the current working directory where the session was launched** — default `./ai-digest-<YYYY-Www>.md` (e.g. `./ai-digest-2026-W25.md`), so the output lands where the user ran the skill, not in a hidden home folder. Honor `--out=<path>` to override (a directory or a full path); `--out=home` restores the legacy `~/.claude/ai-digest/runs/<YYYY-Www>/digest.md`. **Build the path cross-platform** — do NOT hard-code a POSIX `~`/`$HOME` or `stat -f` (a tester is on Windows, where the path is `C:\Users\…\` and `~`/`stat -f` don't exist; use the harness's path tools / the cwd as given). Resolve and report the **absolute** path. If the cwd is a git working tree, add a one-line note: "this file is untracked — add `ai-digest-*.md` to your local `.gitignore` if you don't want it committed."

1. **Reader copy** (clean, paste-into-a-doc-ready) — no preamble, no confidence markers, no raw URLs inline:
   - A 2-3 sentence **TL;DR**.
   - **Closed this week** — top-3, each `<outcome> — <who outside AUT it touches> — <what changed>` (the so-what template).
   - **In progress** — top-3.
   - **Priorities / next** — top-3.
   - A footer line stating the week, the timezone used for the label, and a plain **coverage** note (e.g. "from N closed ClickUp tasks + M call-only items this week").
2. **Editor/audit file** (`./ai-digest-<YYYY-Www>.md` in the cwd by default, or wherever `--out` points) — everything the reader copy hides: every citation (task URLs + Doc-URL#section), the per-pick ranking rationale, the also-ran list, the full Closed/In-progress/Priorities pools, and the preflight + coverage detail. Citations live here, not in the reader copy. Tell the user the **absolute** path on its own line (e.g. `Saved: <abs path>`).

**Empty-state (heartbeat):** if a section has nothing citable, print that section with "— nothing this week —" (and, for Closed, a note if it's because no tasks carried a `date_closed` in-window, **or because the ClickUp connector is date-blind and the status+notes fallback found no in-week note for any Closed-status task** — never a silent empty that reads as "the team did nothing"). Always print the footer.

## After printing — tell the human the next move (do not do it)

End with one line: this is a **draft** — rewrite for voice/outcome, then publish. Note that the digest is **cited, not "verified"** (cross-dept readers should trust the links, not a badge). If Geekbot was OFF, mention it can be enabled locally with `/ai-digest --setup` (on an interactive run, Step 1b already offers this up front). A verified tier and Slack/Doc delivery are deferred to v2.

## Mode: --setup — enable the optional Geekbot source LOCALLY (interactive)

Triggered by `--setup` / `--onboard`. This is the ONLY interactive mode — it asks questions and writes ONE local file. Everything stays on the user's machine; **nothing here is ever committed to the repo or printed back**. Because it is inherently interactive, it is a **no-op under `--yes`/`--non-interactive` or a headless `claude -p` session** — if invoked there, print "setup needs an interactive session — run `/ai-digest --setup` in an interactive Claude Code session" and do nothing else. The shell snippets below assume the **Bash tool** (on Windows that's Git Bash / WSL, where Claude Code's Bash runs); each uses a GNU-first / BSD-fallback form so it works on Linux + Git Bash + macOS alike.

**Frame it for the user up front:** "I'll help you turn on Geekbot for the digest. I'll create a small file in your home folder (`~/.geekbot/env`) and you paste your API key **into that file** — never here in the chat (pasting a secret to me would expose it). The key stays local: never put in the repo, never printed, never sent anywhere. I only read it by name at run time."

Walk these steps, pausing for the human (use AskUserQuestion where a choice is needed):

1. **Tier / key — free if you can.** Ask how many people ACTIVELY answer the AUT standup. If **> 10** → the workspace is already on Basic (Starter caps at 10) → the API key is **free**; generate it at `https://app.geekbot.com/dashboard/api-webhooks`. If **≤ 10** → either upgrade to Basic (~$3/user-mo) OR **borrow a key from someone already on a Basic workspace** (Sashko has one; Andy owns/admins the standup). The key must belong to a **participant of the shared AUT standup** (so it can read everyone — see step 4).

2. **Create the key file FOR them — they paste the key INTO the file, never into this chat.** The whole point: the key must NEVER pass through the chat (pasting a secret to the model = exposing it). So the skill makes a place and the human fills it. First *you* (the skill) create an empty, locked-down key file — this command carries **no secret**, so it's safe for the skill to run:
   ```bash
   mkdir -p ~/.geekbot && ( umask 177; printf 'GEEKBOT_API_KEY=\n' > ~/.geekbot/env ) && chmod 600 ~/.geekbot/env \
   && echo "Created ~/.geekbot/env (chmod 600) — open it and paste your key after the = sign."
   ```
   Then tell the human, in plain words: **"Open the file `~/.geekbot/env` in any editor, paste your Geekbot key right after `GEEKBOT_API_KEY=` (no spaces, no quotes), save it, and tell me 'done'. Do NOT paste the key here in the chat."** Offer an open command for their OS but let them open it however they like: `open -e ~/.geekbot/env` (macOS) · `xdg-open ~/.geekbot/env` (Linux) · `notepad %USERPROFILE%\.geekbot\env` (Windows). **The skill NEVER asks for the key value and NEVER reads it back aloud.**
   When they say "done", verify WITHOUT printing the key (length + file mode only):
   ```bash
   K=$(grep -m1 '^GEEKBOT_API_KEY=' ~/.geekbot/env | cut -d= -f2-); K=${K%$'\r'}; K="${K//[[:space:]]/}"; K=${K#\"}; K=${K%\"}
   if [ -z "$K" ]; then echo "key still empty — open ~/.geekbot/env and paste it after the = sign, then say done";
   elif [ "$K" = "PASTE_YOUR_KEY_HERE" ]; then echo "placeholder still there — replace it with the real key";
   else echo "key present (${#K} chars); mode $(stat -f '%Lp' ~/.geekbot/env 2>/dev/null || stat -c '%a' ~/.geekbot/env)"; fi
   ```
   It prints only the length + permission bits, never the value. If empty/placeholder → loop back (re-ask them to paste + save). This file lives in `$HOME`, outside any git repo; never add it anywhere tracked. (If they keep secrets elsewhere, accept any path and record it in config — but default to `~/.geekbot/env`.)

3. **Resolve the standup id + roster** (reads, never writes Geekbot). Read the key as **data** (never `source` — see RCE note in `references/geekbot-playbook.md`), then call the leak-proof form:
   ```bash
   GEEKBOT_API_KEY=$(grep -m1 '^GEEKBOT_API_KEY=' ~/.geekbot/env | cut -d= -f2-); GEEKBOT_API_KEY=${GEEKBOT_API_KEY%$'\r'}; GEEKBOT_API_KEY="${GEEKBOT_API_KEY//[[:space:]]/}"; GEEKBOT_API_KEY=${GEEKBOT_API_KEY#\"}; GEEKBOT_API_KEY=${GEEKBOT_API_KEY%\"}
   printf 'header = "Authorization: %s"\n' "$GEEKBOT_API_KEY" | curl -sS -K - https://api.geekbot.com/v1/standups/ \
   | python3 -c "import sys,json;[print(s['id'],'|',s['name'],'|',[u['username'] for u in s.get('users',[])]) for s in json.load(sys.stdin)]"
   ```
   Show the list; have the user pick the AUT standup. Capture its `id` and the `users[]` roster (the team).

4. **Coverage test — confirm ONE key reads ALL members.** Pull last week's reports WITHOUT `user_id` and list distinct reporters (key read as data again — same shell as the curl):
   ```bash
   GEEKBOT_API_KEY=$(grep -m1 '^GEEKBOT_API_KEY=' ~/.geekbot/env | cut -d= -f2-); GEEKBOT_API_KEY=${GEEKBOT_API_KEY%$'\r'}; GEEKBOT_API_KEY="${GEEKBOT_API_KEY//[[:space:]]/}"; GEEKBOT_API_KEY=${GEEKBOT_API_KEY#\"}; GEEKBOT_API_KEY=${GEEKBOT_API_KEY%\"}
   WK_AGO=$(date -u -d '7 days ago' +%s 2>/dev/null || date -u -v-7d +%s)   # GNU (Linux / Git Bash on Windows) || BSD (macOS)
   printf 'header = "Authorization: %s"\n' "$GEEKBOT_API_KEY" | curl -sS -K - "https://api.geekbot.com/v1/reports/?standup_id=<ID>&after=$WK_AGO&limit=100" \
   | python3 -c "import sys,json;r=json.load(sys.stdin);print('reports',len(r));print('reporters',sorted({x['member']['username'] for x in r}))"
   ```
   PASS iff the reporters include people **other than the key owner**, covering the roster from step 3. If only the key owner appears → wrong key / per-person standups → go back to step 1 for a key that's a participant of the shared standup. (This is what makes "all reports of all members from one key" work.)

5. **Build the question→bucket map.** From a report row's `questions[]`, list the real standup questions and ask the human to classify EACH: `PAST` (what was done) / `FUTURE` (what's next) / `BLOCKER` / `EXCLUDE` (mood, ambiguous like "what are you working on?"). Never guess tense.

6. **Write the local config** (`~/.claude/ai-digest/config.md`, the skill's own config — not the repo) with the pinned values:
   ```
   Geekbot: standup_id <ID> ("<name>"); roster <usernames>; key GEEKBOT_API_KEY from ~/.geekbot/env (read as DATA via grep|cut, NEVER source, never print).
   Geekbot question map: "<q1>"=PAST | "<q2>"=FUTURE | "<q3>"=BLOCKER | "<mood q>"=EXCLUDE
   ```
   Show the user the file content before writing; write only on confirm.

7. **Done.** Tell them: Geekbot is now ON for `/ai-digest` (enrich-only — it corroborates lines + a "From standups" lane, never originates a theme). It stays OFF on any machine without `~/.geekbot/env`. Re-run `--setup` any time to change it.
