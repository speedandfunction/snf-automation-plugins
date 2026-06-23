# daily-call-tasks

A **3-skill suite** around the calls you attended — turn yesterday's meetings into a cited
digest, into ClickUp tasks, and into a ready-to-post standup. The three skills share the call
extraction logic and the `~/.claude/shared/identity.json` contract.

> Source repo: [`MishaSkripkovsky/daily-call-tasks`](https://github.com/MishaSkripkovsky/daily-call-tasks) · ClickUp 86ca8brqx (digest/commit) · 86cacn12x (morning-brief).

| Skill | Command | Posture | What it does |
|---|---|---|---|
| `daily-call-tasks` | `/daily-call-tasks` | **read-only**, unattended-safe | Cited digest of YOUR action items from yesterday's attended calls. Built to run as a morning cloud routine via `/schedule`. |
| `daily-call-tasks-commit` | `/daily-call-tasks-commit` | **interactive, writes ClickUp** | Review/edit the digest in chat, then create the chosen items as ClickUp tasks (or update a similar one). Self only; writes nothing until you confirm. |
| `morning-brief` | `/morning-brief` | **interactive, posts to Geekbot** | Geekbot-style standup prep: what you did / on your plate / blockers / open questions → auto-post to Geekbot with correct Slack mentions. |

## Requirements
- **All three:** Google **Calendar** + **Drive** connectors. Run per-call sub-agents on **Sonnet**.
- **`-commit` + `morning-brief`:** the **ClickUp MCP**, and a one-time identity (`/morning-brief --onboard` — a self-contained wizard that writes `~/.claude/shared/identity.json`; no other plugin required).
- **`morning-brief` optional (degrade gracefully if absent):** a **Geekbot** API key (`GEEKBOT_API_KEY`) for auto-post, the **Gmail** connector for the Emails section, and a `~/Work/team.md` roster for `<@SlackID>` mentions.

## The morning digest (`/daily-call-tasks`)
Reads your Calendar for attended events, pulls the notes-bot **Meeting Resources → Meeting Notes**
(and any transcript), and uses Sonnet sub-agents to extract *your* action items with verbatim
citations. **Read-only and unattended-safe:** it never asks questions, never invents an item, and
never writes to Calendar/Drive/ClickUp/Slack. The printed digest *is* the delivery — run it as a
daily routine (`/schedule`) and read the result in the Claude app each morning.

```text
/daily-call-tasks --since=yesterday              # print the digest
/daily-call-tasks --since=yesterday --dry-run    # same (already read-only)
```

## Send the digest to ClickUp (`/daily-call-tasks-commit`)
The interactive write step. Review the grouped list, edit by exception, pick a destination list,
and on confirmation each item is CREATEd (or a similar existing task is UPDATEd after a
before→after diff). **Writes only on your explicit confirmation**, self only (others' items are
flagged `UNATTRIBUTED`, never auto-committed), updates touch name/description only, and re-runs
don't duplicate (hidden idempotency marker). Refuses to run unattended.

```text
/daily-call-tasks-commit --since=yesterday --dry-run    # preview the create/update plan
/daily-call-tasks-commit --since=yesterday              # review/edit → confirm → writes
```

## Standup prep (`/morning-brief`)
One interactive command assembles five sections — **Done** (attended meetings + ClickUp status
changes, with "sent for review *to whom*" resolved from the task's assigned comments), **On your
plate** (open tasks + not-yet-ticketed call items), **Blockers**, **Open questions** (@-mentioned
via a `team.md` roster), and optionally **Emails** — then, on confirmation, posts to Geekbot.
Read-only against ClickUp/Calendar/Drive; the only writes are the self-onboarded identity file and
the **confirmed** Geekbot post. Fails closed on any unresolved `@mention`.

```text
/morning-brief --onboard     # one-time identity wizard (writes ~/.claude/shared/identity.json)
/morning-brief --status      # show which dependencies are connected / degraded
/morning-brief --no-post     # compose + print the brief, never post to Geekbot
/morning-brief               # full run → confirm → post
```
> First release: the Geekbot auto-post path hasn't been exercised end-to-end — run with `--no-post` first to preview before relying on the live post.

## Guarantees (per skill)
- `daily-call-tasks` — **read-only**, zero writes to any service; Sonnet sub-agents; never invents an item; always emits a result.
- `daily-call-tasks-commit` — writes to **ClickUp only on explicit confirmation**; self only; never closed/others' tasks; idempotent re-runs.
- `morning-brief` — read-only except the self-onboarded identity file + the **confirmed** Geekbot post; self only; fails closed on unresolved mentions.

## Layout
```
skills/
  daily-call-tasks/          SKILL.md  references/extraction.md
  daily-call-tasks-commit/   SKILL.md  references/commit-rules.md
  morning-brief/             SKILL.md  references/{onboarding,sections}.md
commands/                    daily-call-tasks.md · daily-call-tasks-commit.md · morning-brief.md
```
