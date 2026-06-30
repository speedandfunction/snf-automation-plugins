# daily-call-tasks

**One skill, one command** for the calls you attended. It reads your Google Calendar for the
meetings you actually joined, pulls the notes-bot **Meeting Notes / transcript** for each, and uses
**Sonnet** sub-agents to extract the action items with verbatim citations — then renders them as
**one table per meeting** and (on a manual run) offers to push the chosen tasks to ClickUp.

> Source: ClickUp 86ca8brqx. v2.0 merges the former read-only `daily-call-tasks` digest and the
> interactive `daily-call-tasks-commit` into a single command (Andy's 2026-06-24 redesign).

## The table (used everywhere — scheduled and manual)
**One table per meeting** (N meetings → N tables). Above each table, a heading
`<meeting name> · <date + time> · <participants>`. Columns, in order:

```
<Meeting name> · 2026-06-24 14:00 · Andriy, Misha, Yulia
| № | task name | priority | status | deadline | assignee | description |
|---|-----------|----------|--------|----------|----------|-------------|
| 1 | Ship the digest fix | high | To-Do | 2026-06-30 | Misha | from the standup discussion |
| 2 | Draft the onboarding lesson |  | Backlog |  | Misha |  |

<Another meeting> · 2026-06-24 16:30 · Andriy, Sasha
| № | task name | priority | status | deadline | assignee | description |
|---|-----------|----------|--------|----------|----------|-------------|
| 3 | Review the marketplace PR | urgent | To-Do | 2026-06-25 | Andriy |  |
```

Numbering is **continuous across all tables** in the run (table 2 starts where table 1 ended), so
you can say "push 1, 3" or "prio 2: high". Every cell is filled only when the call actually voiced
it — blank, never invented. Each row keeps its verbatim citation (used as the created task's
description).

## Two ways it runs (auto-detected — no mode flags)
- **Scheduled / unattended** (no human / no TTY) → window = **yesterday**, renders the tables
  **read-only**. Never asks, never writes. Run it as a daily cloud routine with `/schedule`; the
  routine's session is what you read each morning.
- **Manual / interactive** (a human is present) → **asks the period** (+ optional
  participants/team filter — e.g. "only meetings with the automation team"), renders the same
  tables, then asks **"add to ClickUp / fix anything?"**.

The run model is detected from explicit signals (an explicit mode/window param, a scheduler/cron
context, or the morning window), failing closed to scheduled/read-only when unsure — a TTY probe is
only a corroborating hint, never the sole determinant. The ClickUp write also sits behind an
`AskUserQuestion` gate, so a scheduled session physically can't reach it.

## Edit + push (manual only)
Reply with task numbers and edit-by-exception, then `push to ClickUp`:

```
edit 4: <new title>     desc 4: <text>
prio 5: high            due 4: 2026-06-30   (or  due 4: none)
status 3: backlog       assignee 6: <name>
drop 7                  add 7               list 4: <list>
push to ClickUp         cancel
```

On `push to ClickUp` it shows a COMMIT PLAN and asks to Confirm, then creates the chosen tasks in
the **automation space** with status / priority / deadline / assignee set. **Team-assign is
allowed** (assign to a teammate) but gated: a cross-person assignee is eligible only from the team
filter you chose or a name you type (never from doc text alone); the eligible name is then resolved to one workspace member
and shown in the plan first, and the Confirm names the cross-person scope, so it never silently
mis-assigns and a poisoned notes doc can't fan tasks out to teammates. Re-runs don't duplicate (a
hidden idempotency marker; already-committed rows are skipped).

## Requirements
- **Google Calendar + Google Drive** connectors (at `claude.ai/customize/connectors`).
- Per-call sub-agents on **Sonnet** — pin `CLAUDE_CODE_SUBAGENT_MODEL=claude-sonnet-4-6` (HARD
  requirement). Mac/Linux/Git-Bash: `export CLAUDE_CODE_SUBAGENT_MODEL=claude-sonnet-4-6` in the
  shell that launches Claude Code (or add to `~/.zshrc` / `~/.bashrc`); Windows PowerShell:
  `$env:CLAUDE_CODE_SUBAGENT_MODEL = "claude-sonnet-4-6"`. Verify with `echo
  $CLAUDE_CODE_SUBAGENT_MODEL`.
- **ClickUp MCP** — only needed for the manual push. For team (non-self) assignees, name resolution
  reads the portable **`~/.claude/shared/identity.json` `teammates[]` (PRIMARY)**, falling back to
  the author-local **`~/Work/team.md` (FALLBACK)**, then `clickup_resolve_assignees`. (Same roster
  source `/morning-brief` and `/clickup` use.) A cross-person create (assigning to someone other than
  you) is only eligible from the team filter you chose or a name you type, never from doc text alone,
  and always asks you to confirm the cross-person scope first.
- A transcript notetaker (e.g. Sembly) is **optional** — the skill runs notes-only without it, and
  promotes the transcript when a Meeting Notes doc 403s.

## Guarantees
- **Extraction is read-only** — zero writes to Calendar / Drive / transcripts / Slack / Gmail.
- The **only** write is the ClickUp create, reachable only in a manual session and only after your
  explicit "push to ClickUp" + Confirm.
- **Never invents** an item, priority, deadline, assignee, or description — blank when unvoiced;
  every row carries a citation.
- **Scheduled runs never prompt and never write.** Idempotent re-runs (marker-first dedup).

## Layout
**COMMAND layout** — this is what registers the clean bare `/daily-call-tasks` (a plugin SKILL, root or
`skills/<name>/`, is ALWAYS namespaced `/daily-call-tasks:daily-call-tasks`; only a COMMAND is bare —
proven by the official `code-review`/`feature-dev` plugins). The instruction body lives in
`commands/daily-call-tasks.md`; there is deliberately NO `SKILL.md` and NO `skills/<name>/` — do not "restore" them.
```
daily-call-tasks/
  commands/daily-call-tasks.md   # the instruction body → bare /daily-call-tasks
  references/{extraction.md, commit-rules.md}   # read via ${CLAUDE_PLUGIN_ROOT}/references/…
  .claude-plugin/plugin.json
  README.md  QUICKSTART.md
```
