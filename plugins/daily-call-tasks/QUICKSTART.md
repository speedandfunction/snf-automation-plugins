# Quickstart — daily-call-tasks (one skill, one command)

A primitive "how to launch it" — paste the block at the bottom into your team channel.

## Install (once)
```text
/plugin marketplace add speedandfunction/snf-automation-plugins
/plugin install daily-call-tasks@snf-automation-plugins
/reload-plugins
```

## Connect (once)
1. Connect **Google Calendar** + **Google Drive** at `claude.ai/customize/connectors`.
2. For the ClickUp push, connect the **ClickUp** connector too.
3. Make sure per-call sub-agents run on **Sonnet** — this env var is a HARD requirement. In the shell
   that launches Claude Code (Mac/Linux/Git-Bash):
   ```bash
   export CLAUDE_CODE_SUBAGENT_MODEL=claude-sonnet-4-6
   ```
   (add it to `~/.zshrc` / `~/.bashrc` to persist; Windows PowerShell:
   `$env:CLAUDE_CODE_SUBAGENT_MODEL = "claude-sonnet-4-6"`). Verify: `echo $CLAUDE_CODE_SUBAGENT_MODEL`
   prints `claude-sonnet-4-6`.

## Use it
```text
/daily-call-tasks                          # manual: it asks the period (+ optional team filter)
/daily-call-tasks last 3 days              # manual with the period passed inline
/daily-call-tasks yesterday, automation team only
```

- **Scheduled** (via `/schedule`): pulls **yesterday** automatically, prints the tables read-only —
  no questions, no writes. The routine's session is your morning digest.
- **Manual**: it asks the period (+ optional participants/team filter), then renders **one table per
  meeting** (`№ | task name | priority | status | deadline | assignee | description`, continuous
  numbering across tables) and asks **"add to ClickUp / fix anything?"**.

Edit by exception, then push:
```text
prio 2: high     status 3: backlog     assignee 6: Andriy     drop 7
push to ClickUp
```
It shows a COMMIT PLAN, asks you to Confirm, then creates the chosen tasks in the **automation
space** (status/priority/deadline/assignee set; team-assign allowed but always confirmed; re-runs
don't duplicate).

## Optional
- A transcript notetaker (Sembly) — promoted automatically when a Meeting Notes doc 403s.
- **`~/.claude/shared/identity.json` `teammates[]` (PRIMARY)** — the portable roster (shared with
  `/morning-brief` and `/clickup`) used to resolve a team name to its members for the participants
  filter and team-assign. **`~/Work/team.md` is a FALLBACK** for the author's local machine; a public
  install resolves teams from identity.json. (A cross-person create only ever uses a member from the
  filter you chose or a name you type, never a teammate named only inside the notes doc.)

---

## Ready-to-paste channel message
> **🗓 Daily Call Tasks — try it (5 min)**
> A Claude Code plugin: it turns *the calls you attended* into a cited table of action items — one
> table per meeting (priority/status/deadline/assignee), and on a manual run pushes the ones you
> pick straight to ClickUp.
> 1. Paste into Claude: `/plugin marketplace add speedandfunction/snf-automation-plugins` then `/plugin install daily-call-tasks@snf-automation-plugins` then `/reload-plugins`
> 2. Connect Google Calendar + Drive (+ ClickUp for the push) at claude.ai/customize/connectors.
> 3. Run `/daily-call-tasks` — it asks the period, shows the tables, and offers to push to ClickUp.
> Schedule it with `/schedule` to get yesterday's tables every morning (read-only).
> Marketplace: https://github.com/speedandfunction/snf-automation-plugins/tree/main/plugins/daily-call-tasks
