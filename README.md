# snf-automation-plugins

Speed & Function **Automation department's** Claude Code plugin marketplace — internal tooling
for the **MN Service** (Meeting Notes) n8n pipeline and daily call digests.

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

```text
/plugin install mn-team-onboard@snf-automation-plugins
/plugin install daily-call-tasks@snf-automation-plugins
```

## Plugins

| Plugin | Command | What it does | Requirements |
|---|---|---|---|
| **mn-team-links** | `/mn-team-links [team]` | Read-only. Resolves an MN Service team → its Google Drive transcript/notes folder link, live from the n8n config. | **n8n MCP** connected. (No secret needed for normal use.) |
| **mn-team-onboard** | `/mn-team-onboard <tag> <parentUrl> [slack]` | Writer. Onboards a new team: creates Drive subfolders via a token-protected n8n webhook + adds one `teamsRaw` routing entry (Stage→Prod), self-validated with rollback. | **n8n MCP** + **Google Drive** connector + webhook token in `plugins/mn-team-onboard/.env` (see `config/.env.example`). |
| **daily-call-tasks** | `/daily-call-tasks [--since=…]` | Read-only, unattended-safe. Cited digest of YOUR action items from yesterday's attended calls; built to run as a morning cloud routine via `/schedule`. | **Google Calendar** + **Google Drive** connectors. Run sub-agents on **Sonnet**. |

> If a plugin produces empty output, check its Requirements above first — e.g. `mn-team-links`
> with no n8n MCP connected, or `daily-call-tasks` with no Google connectors.

## Layout

```
.claude-plugin/marketplace.json   # marketplace manifest (lists the 3 plugins)
plugins/<name>/
  .claude-plugin/plugin.json      # plugin manifest
  skills/<name>/SKILL.md          # the skill
  commands/<name>.md              # thin slash-command wrapper
  scripts/ | reference/ | config/ # supporting files (where applicable)
```

Bundled scripts are addressed via `${CLAUDE_PLUGIN_ROOT}` so they resolve regardless of CWD.

## Notes

- Source skills also live in their own repos (`MishaSkripkovsky/mn-team-links`,
  `…/mn-team-onboard`, `…/daily-call-tasks`); this marketplace is the installable distribution.
- No secrets are committed — only `*.env.example` templates. Real `.env` files are gitignored
  and live only locally / per-install.
