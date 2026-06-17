# ai-digest

A Claude Code skill that drafts the automation department's **weekly cross-department digest** — three short sections (**Closed this week**, **In progress / discussed**, **Priorities / next**), each capped to a top-3, every line **cited**, written as *outcomes for other departments* rather than a worklog.

It is **notes-led**: the team's own meeting-notes are the primary narrative; **ClickUp** supplies the dated "what closed" signal and the priority backlog. The output is a **print-only draft a human rewrites** and the lead publishes — it never auto-posts. Read-only against Google Drive + ClickUp.

> ClickUp 86ca8brqx (digest task) · scaffold adapted from Sasha Marchuk's MIT [`log-time`](https://github.com/SashaMarchuk/claude-plugins) + the sibling [`daily-call-tasks`](../daily-call-tasks) skill.

## Honest by design — no "verified" claims
On every row the person who closed the ticket, wrote the note, and spoke on the call is the **same person** — there is no independent witness, so the digest makes **no "verified / corroborated" claims and shows no confidence badge**. The bucket is *"Closed this week (per ClickUp)"* and the **citation is the proof**. The human editor + an AUT-internal dry-run are the real trust layer.

## v0 scope (decided by review; rest is v2)
- **In:** AUT meeting-notes (primary) + ClickUp (dated signal), cited, print-only draft, top-3 per section, so-what translation + anti-worklog verb-lint.
- **v2:** Geekbot per-person signal · a verified tier · fuzzy call↔task join · Slack/Doc delivery · deterministic ranking.

## Try it locally (dry-run)
From inside this repo (so the project skill is discovered), pre-approving the read-only tools it needs:

```bash
claude -p "/ai-digest --week=last --dry-run" \
  --allowedTools "Read,Bash,mcp__clickup__clickup_filter_tasks,mcp__clickup__clickup_get_workspace_hierarchy,mcp__clickup__clickup_get_task,mcp__claude_ai_Google_Drive__read_file_content,mcp__claude_ai_Google_Drive__search_files"
```

Prerequisites: a connected **ClickUp** MCP and a **Google Drive** connector with read access to the AUT notes folder (`1Rzb…`; if the running account isn't shared into the notes-bot folder you'll get a 403 — share it read-only). To pin gather sub-agents to Sonnet locally: `export CLAUDE_CODE_SUBAGENT_MODEL=claude-sonnet-4-6`.

What to verify in the output:
- **Scope** — does it cover the whole AUT space (`[AUT]/[MNB]/[MAR]/[CLT]/[HR]/[TDE]/Q2` initiatives), not a subset?
- **Closed** — every "Closed this week" item has a real `date_closed` in the week and a task URL; no `review`/null-date_closed leaks; no closed-child + open-parent double-count; no `Step 1/2/3` noise.
- **Honesty** — no "verified/shipped" on research/review/sync cards; no confidence badges; thin sections stay thin (no padding).
- **Narrative** — does it read like outcomes for another department, or a list of tickets?

## Config (optional — defaults baked in)
Defaults target the S&F automation department: ClickUp space `90156104627`, notes folder `1Rzb1nVmvlKf_enEkWB2q6tcixDgiC0sx`. Override via `~/.claude/ai-digest/config.md` (free-form) if those change. Roster names resolve from the shared `~/.claude/shared/identity.json` (same file `/clickup` + `/gevent` use); read-only.

## Layout
```
plugins/ai-digest/
  .claude-plugin/plugin.json
  commands/ai-digest.md
  skills/ai-digest/
    SKILL.md                     # the brain: scope, gather, buckets, rank, emit
    references/clickup-playbook.md  # whole-space scope, date_closed!=null, subtask roll-up, status buckets
    references/output-style.md      # so-what template, verb-lint, no-verification rule
  tests/run.sh                   # doc-contract test for the load-bearing invariants
```

## Guarantees
- Read-only — zero writes to ClickUp / Drive / Slack / anywhere; never auto-posts.
- Cite-or-drop — no line without a real ClickUp URL or Meeting-Notes Doc section.
- No verification vocabulary; `date_closed` is labelled "closed", never auto-"shipped".
- Always emits a result (even "nothing this week") so a silent failure is distinguishable from a quiet week.
