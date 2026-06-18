---
name: ai-digest
description: Drafts a weekly cross-department "AI Automation digest" for the Speed & Function automation team — top-3 Closed-this-week / In-progress / Priorities, so other departments can see what the team is doing. Notes-led: the team's own meeting-notes are the primary narrative; ClickUp supplies the dated "what closed" signal and the priority backlog. Every line is cited; the output is a PRINT-ONLY draft a human edits and the lead publishes — it never auto-posts. Read-only against Google Drive + ClickUp. Makes NO "verified/corroborated" claims (the author of the note, the ticket, and the call are the same person — the citation, not a confidence badge, is the honesty). Use when the user wants to draft the weekly AI-Automation department digest, a cross-dept progress update, or "what did the automation team ship/work on this week". v0 prints the draft only — no Geekbot, no fuzzy call↔task join, no delivery (all v2).
user-invocable: true
---

# /ai-digest — Weekly AI-Automation Digest (v0: notes + ClickUp, print-only draft)

Draft the automation department's **weekly cross-department digest**: three short sections — **Closed this week**, **In progress / discussed**, **Priorities / next** — each capped to a top few, every line **cited**, written so a reader in another department understands the *outcome*, not the worklog. The output is a **draft a human rewrites**; the lead publishes it. This skill is **read-only** and **never auto-posts**.

> **Provenance.** The skill scaffold (config-driven sources, preflight, parallel sonnet fan-out, two-output emit, read-only + "never print credentials" discipline) is adapted from Sasha Marchuk's MIT-licensed `log-time` skill (github.com/SashaMarchuk/claude-plugins) and the sibling `daily-call-tasks` skill in this marketplace. The digest brain (buckets, ClickUp playbook, ranking, so-what translation, anti-worklog rules) is original.

## What this is NOT (v0 scope — decided by review, deferred to v2)

- **No "verified" / "corroborated" / 🟢 tier and no confidence badges.** On every row the person who closed the ticket, wrote the note, and spoke on the call is the *same person* — there is no independent witness, so a "verified" label would overclaim to other departments. The **citation is the honesty**. Say "Closed this week (per ClickUp)", never "Verified/Shipped".
- **No Geekbot (v2).** Geekbot uniquely carried per-person *forward-looking* intent/blockers, so **the Priorities bucket is the weaker one in v0** — it's reconstructed from ClickUp open/priority items + the notes' next-steps, which is a proxy, not the standup signal. Closed/In-progress are solid; Priorities is "best available".
- **Calls = the Meeting-Notes Docs, not raw transcripts.** The skill reads the auto-generated **Meeting-Notes Doc** for each AUT call (the dept's own call output), not the raw transcript and not Geekbot. A call with no notes section is invisible to it — acceptable because the notes bot covers AUT calls, but say so if a known call is missing.
- **No fuzzy call↔task join.** Only an exact ClickUp task-id/URL appearing in a note links the two; otherwise the note and the task stand on their own citations. (Fuzzy join = v2.)
- **No delivery, no ticket writes, no auto-post.** Print-only. (Slack/Doc delivery = v2.)
- **No lexicographic ranking determinism.** v0 ranks by an LLM top-N with a shown rationale + a stable sort key. (Deterministic scoring = v2.)

## Invocation & flags (parse first)

| Flag | Meaning | Default |
|---|---|---|
| `--week=<when>` | Target ISO week: `last` (default), `this`, `YYYY-Www` (e.g. `2026-W25`), or any `YYYY-MM-DD` (the ISO week containing that date) | `last` |
| `--dry-run` / `--print-only` | Print the draft only (also the default behavior) | on |
| `--tz=<IANA>` | Timezone for the human-readable week label only; the data window is computed in **UTC** (see Step 2) | resolved per Step 0 |
| `--max-subagents=N` | Cap on parallel gather sub-agents | `4` |

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
- **Identity / roster (optional):** read `~/.claude/shared/identity.json` if present (the same file `/clickup` and `/gevent` write; read-only — never write it) for `user`, `teammates[]`. Used only for attribution labelling; never HALT if absent.
- **Providers (detect from the session tool list; prefer-then-fallback — get the data):**
  - ClickUp: the connected ClickUp MCP (`mcp__clickup__clickup_filter_tasks`, `clickup_get_task`, `clickup_get_workspace_hierarchy`).
  - Notes: a Google Drive MCP/connector (`mcp__*Google_Drive*__*`) to list + read the notes folder's Docs.
  - If a custom source in the config needs a credential (an env var / file), load it silently and **never print, echo, or log the secret value**.

## Step 1 — PREFLIGHT (probe each source, do not gather yet)

Probe each source with the smallest possible read and print a table `[OK | BROKEN | OFF] <source> — <note>`:
- **ClickUp** — one `clickup_get_workspace_hierarchy` on the space (confirms reach + lists/statuses). On auth-fail, surface the re-auth hint and STOP that source (don't silently proceed).
- **Notes** — reachability is NOT enough; you MUST confirm there is **parseable content for the target week**. List the notes folder (403 trap = the running account isn't shared into the notes-bot folder → say so), then open the rolling Meeting-Notes Doc and confirm **≥1 `### *Date:*` section falls inside the week window**. Try BOTH header spellings `### *Date:*` and `### Date:` (the header drifted once before) and warn if only the non-asterisk form matches. If the folder is reachable but **no in-week date-section parses**, mark Notes **DEGRADED** (not OK) — do not silently treat it as present.

If **both** are BROKEN, print the preflight table and stop with a one-line reason — never emit a confident-but-empty digest. If Notes is BROKEN/DEGRADED but ClickUp is OK, proceed **ClickUp-only** and the coverage footer MUST say so explicitly ("notes unavailable this week — ClickUp-only; this digest is a task list, not the full narrative") — this is the guard against silently shipping a closed-ticket worklog that reads as "the team did little".

## Step 2 — SCOPE (the week window, in UTC)

Resolve the **ISO week** from `--week` (default `last` = the most recently completed Mon–Sun). Compute the window as a **UTC** `[from, to)` (Mon 00:00 UTC → next Mon 00:00 UTC). Both sources are sliced on this same UTC boundary so an item closed/discussed at a week edge can't half-belong. Print the resolved week + UTC window + (for the human label only) the `--tz`/config timezone. Per the closures: the notes Docs render their `### *Date:*` headers in **UTC**, so UTC is the correct join clock.

## Step 3 — GATHER (parallel sonnet sub-agents, artifacts only)

First, the orchestrator (you) reads `references/clickup-playbook.md` and `references/output-style.md` ONCE from the skill dir resolved in Step 0 (one direct `Read` each — never search for them). Then launch the source sub-agents **in one message** (parallel), **pasting the relevant rules inline into each sub-agent's prompt**. Sub-agents work ONLY from their prompt + the MCP tools — they MUST NOT open, read, or `find` any skill file (a fresh sub-agent doesn't know the skill path; telling it to "follow references/…" is what triggers a disk-wide `find` that hangs). Cap at `--max-subagents`. Each sub-agent writes its findings to a run artifact and returns a compact summary.

- **ClickUp sub-agent** — give it these rules inline (the full version is in `references/clickup-playbook.md`): one `clickup_filter_tasks` call per pool over the whole space `90156104627` with `subtasks=true` (paginate via `page` only until a page returns 0). **The `filter_tasks` response already contains `date_closed`, `status`, `assignees`, `list`, `url` for every task — do NOT call `get_task` per task** (that turns ~60 tasks into hundreds of calls). Then in-prompt: **post-filter `date_closed != null` and inside the UTC week** (the `review` status is done-type with a null `date_closed` and leaks into a date-window query); roll up closed child subtasks to their parent and **de-dup** (never a closed child + its open parent as two; suppress `^Step \d+` recurring leaves). Produce three raw pools: **Closed** (date_closed in week), **In-progress** (open + moved this week, status in the active set, minus the deny-list), **Priorities** (open + priority/due). Tag each task with its initiative prefix (`[AUT]/[MNB]/[MAR]/[CLT]/[HR]/[TDE]/Q2`), assignee, list, and URL. Target ≤ ~6 tool calls total.
- **Notes sub-agent** — read the **full body** of the AUT notes folder's rolling Meeting-Notes Doc(s) (NOT the Drive content-snippet — it strips the load-bearing `*` in `### *Date:*`). Slice to the week's `### *Date:*` sections. Extract, with Doc-URL + section citations: decisions, outcomes, owners, **next-steps / action points**, and **non-ticketed work** (research, firefighting, anything discussed that may never become a ticket — this is what keeps the digest a narrative, not a ticket dump).

## Step 4 — SYNTHESIZE (build the three buckets, notes-led)

Merge the artifacts into three sections. **De-dup** across sources and weeks by **initiative prefix** + normalized title; an exact ClickUp task-id/URL found in a note attaches that note's narrative to the task (the only allowed join). Each item carries ≥1 citation.

- **Closed this week (per ClickUp)** — closed tasks, grouped by initiative. Each line: the outcome (notes narrative if the task is mentioned, else the task name rewritten as an outcome) + so-what + the task URL. Apply the **verb-lint** (`references/output-style.md`): never say "shipped/delivered" on a Research/Investigate/Review/Sync/housekeeping card — `date_closed` means "the card was closed", not "a product shipped". Classify ship vs research vs admin in the so-what.
- **In progress / discussed** — notes-led narrative of what the team worked on + ClickUp in-progress items. This is the section that makes it a story, not a worklog.
- **Priorities / next** — ClickUp open + priority/due + the notes' next-steps/action-points. Do **not** gate on `due_date` (it's sparse).

## Step 5 — RANK (top-3 per section + also-ran)

For each section, pick the **top 3** by significance for an outside reader — cross-dept impact, a real outcome/shipment, a named artifact, breadth — with a **one-line rationale per pick** (shown in the editor file). Recurring/admin items rank low. Ties keep both; thin sections under-fill (3 is a ceiling, never a quota — never pad). Everything not in the top-3 goes to the **also-ran** list in the editor file, so the human can see and re-promote what the model cut.

## Step 6 — EMIT (two outputs, print-only)

Before emitting, run two **gates** (don't just assert them — perform them and report the counts in the editor file):
- **verb-lint gate** — scan every reader-facing line for ship-vocab (`shipped/delivered/launched/released`); for each hit, check the underlying card type per `references/output-style.md`; rewrite any on a Research/Investigate/Spike/Review/Sync/Evaluate/Audit/housekeeping card. Log `verb-lint: N lines checked, M rewritten`. A card whose name doesn't match the keyword list but is clearly housekeeping (e.g. "Close out … leftovers") is still demoted from ship-vocab — judge by the work, not just the keyword.
- **consistency check** — every reader-copy line must have a matching citation in the editor file; assert the reader top-3 ⊆ the editor pools and that no reader line is uncited. Report `cite-check: K reader lines, K cited`.

Then print **both** outputs. Write run artifacts under `~/.claude/ai-digest/runs/<YYYY-Www>/` (gitignored, local).

1. **Reader copy** (clean, paste-into-a-doc-ready) — no preamble, no confidence markers, no raw URLs inline:
   - A 2-3 sentence **TL;DR**.
   - **Closed this week** — top-3, each `<outcome> — <who outside AUT it touches> — <what changed>` (the so-what template).
   - **In progress** — top-3.
   - **Priorities / next** — top-3.
   - A footer line stating the week, the timezone used for the label, and a plain **coverage** note (e.g. "from N closed ClickUp tasks + M call-only items this week").
2. **Editor/audit file** (`digest.md` in the run dir) — everything the reader copy hides: every citation (task URLs + Doc-URL#section), the per-pick ranking rationale, the also-ran list, the full Closed/In-progress/Priorities pools, and the preflight + coverage detail. Citations live here, not in the reader copy. Tell the user the path.

**Empty-state (heartbeat):** if a section has nothing citable, print that section with "— nothing this week —" (and, for Closed, a note if it's because no tasks carried a `date_closed` in-window — never a silent empty that reads as "the team did nothing"). Always print the footer.

## After printing — tell the human the next move (do not do it)

End with one line: this is a **draft** — rewrite for voice/outcome, then publish. Note that the digest is **cited, not "verified"** (cross-dept readers should trust the links, not a badge). Mention that Geekbot per-person signal, a verified tier, and Slack/Doc delivery are deferred to v2.
