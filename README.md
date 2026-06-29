# snf-automation-plugins

Speed & Function **Automation department's** Claude Code plugin marketplace — internal tooling
for the **MN Service** (Meeting Notes) n8n pipeline, daily call digests, and standup prep.

## Install

```text
/plugin marketplace add speedandfunction/snf-automation-plugins
/plugin install mn-team-links@snf-automation-plugins
/reload-plugins
```

- The first command registers this marketplace (use the GitHub `owner/repo` path).
- The install identifier is `<plugin>@snf-automation-plugins` — the `@` suffix is the
  **marketplace name** from `marketplace.json` (`snf-automation-plugins`), **not** the repo path.
- Plugins don't appear until you run `/reload-plugins` (or restart Claude Code).

Install any subset:

<!-- BEGIN:AUTOGEN install -->
```text
/plugin install mn-team-links@snf-automation-plugins
/plugin install mn-team-onboard@snf-automation-plugins
/plugin install daily-call-tasks@snf-automation-plugins
/plugin install morning-brief@snf-automation-plugins
/plugin install ai-digest@snf-automation-plugins
```
<!-- END:AUTOGEN install -->

## Plugins

<!-- The table below is AUTO-GENERATED from .claude-plugin/marketplace.json + each plugin's plugin.json
     by scripts/gen-readme.mjs (CI regenerates it on every push). To add/change a plugin, edit the
     manifests — NOT this table. -->
<!-- BEGIN:AUTOGEN plugins -->
| Plugin | Command | What it does | Requirements |
|---|---|---|---|
| **[mn-team-links](https://github.com/speedandfunction/snf-automation-plugins/tree/main/plugins/mn-team-links)** | `/mn-team-links [team]` | Resolve an MN Service team to its Google Drive transcript/notes folder link, read live from the n8n MN Service config via the connected n8n MCP. | **n8n MCP** connected. (No secret needed for normal use.) |
| **[mn-team-onboard](https://github.com/speedandfunction/snf-automation-plugins/tree/main/plugins/mn-team-onboard)** | `/mn-team-onboard <tag> <parentUrl> [slack]` | Onboard a new team to the MN Service pipeline from a team tag + parent Drive folder link: creates Drive subfolders via a token-protected n8n webhook and adds one teamsRaw routing entry (Stage then Prod), self-validated with rollback. | **n8n MCP** + **Google Drive** connector + webhook token in `plugins/mn-team-onboard/.env` (see `config/.env.example`). |
| **[daily-call-tasks](https://github.com/speedandfunction/snf-automation-plugins/tree/main/plugins/daily-call-tasks)** | `/daily-call-tasks` | One skill, one command for the calls you attended. | **Google Calendar** + **Google Drive** connectors; per-call sub-agents on **Sonnet** (`CLAUDE_CODE_SUBAGENT_MODEL=claude-sonnet-4-6`). The manual ClickUp push also needs the **ClickUp MCP**; for non-self (team) assignees it resolves names via `~/Work/team.md` / `~/.claude/shared/identity.json` and `clickup_resolve_assignees`. A transcript notetaker (e.g. Sembly) is optional. Scheduling is per-user via `/schedule`. |
| **[morning-brief](https://github.com/speedandfunction/snf-automation-plugins/tree/main/plugins/morning-brief)** | `/morning-brief` | Interactive Geekbot-style standup prep — one command, no flags. | **Google Calendar** + **Google Drive** + **ClickUp** connectors; sub-agents on **Sonnet**. Optional: a **Geekbot** API key (auto-post), the **Gmail** connector (emails), a **team.md** roster (Slack mentions). One-time identity is created transparently on first run. |
| **[ai-digest](https://github.com/speedandfunction/snf-automation-plugins/tree/main/plugins/ai-digest)** | `/ai-digest` | Drafts the automation department's weekly cross-department digest (top-3 Closed-this-week / In-progress / Priorities) from the team's own meeting-notes (primary narrative) + ClickUp (the dated 'what closed' signal). | **ClickUp MCP** + a **Google Drive** connector. Optional **Geekbot** key enables the enrich-only 3rd source. |
<!-- END:AUTOGEN plugins -->

> If a plugin produces empty output, check its Requirements above first — e.g. `mn-team-links`
> with no n8n MCP connected, or `daily-call-tasks` with no Google connectors.

## Layout

```
.claude-plugin/marketplace.json   # marketplace manifest — the CANONICAL plugin list
plugins/<name>/
  .claude-plugin/plugin.json      # plugin manifest (+ command/requirements for the README table)
  SKILL.md                        # SINGLE-SKILL plugin → SKILL.md at the plugin ROOT
  references/                     # supporting docs the skill reads (relative to SKILL.md)
  scripts/ | config/              # other supporting files (where applicable)
  # MULTI-skill plugins instead use skills/<name>/SKILL.md (+ optional commands/<name>.md)
scripts/gen-readme.mjs            # regenerates this README's plugin table from the manifests
.github/workflows/readme.yml      # CI: runs gen-readme on every push, auto-commits the result
```

### Naming convention
A **single-skill plugin** puts its `SKILL.md` at the **plugin root** (not `skills/<name>/`). Claude Code
then registers it as a clean **`/<plugin>`** — e.g. `/morning-brief`, `/daily-call-tasks` — with **no
doubled `plugin:skill`** namespace. (A plugin that genuinely ships several skills uses `skills/<name>/`,
invoked as `/<plugin>:<skill>`.) The plugin name IS the command; keep them identical and singular.

Bundled scripts are addressed via `${CLAUDE_PLUGIN_ROOT}` so they resolve regardless of CWD.

### Auto-generated README
The **Install list** and **Plugins** table above are generated from the manifests by
`scripts/gen-readme.mjs` (between the `AUTOGEN` markers). **To add or change a plugin, edit
`.claude-plugin/marketplace.json` + the plugin's `plugin.json` — never hand-edit the table.**
A GitHub Action (`.github/workflows/readme.yml`) reruns the generator on every push and commits
any change, so the README stays in sync by itself. Locally: `node scripts/gen-readme.mjs` (or
`--check` to verify it's current, which is what CI enforces).

## Notes

- Source skills also live in their own repos (`MishaSkripkovsky/mn-team-links`,
  `…/mn-team-onboard`, `…/daily-call-tasks`); this marketplace is the installable distribution.
- No secrets are committed — only `*.env.example` templates. Real `.env` files are gitignored
  and live only locally / per-install.
