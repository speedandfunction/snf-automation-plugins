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
| **[daily-call-tasks](https://github.com/speedandfunction/snf-automation-plugins/tree/main/plugins/daily-call-tasks)** | `/daily-call-tasks` | One skill, one command for the calls you attended. | **Google Calendar** + **Google Drive** connectors; per-call sub-agents on **Sonnet** — set `CLAUDE_CODE_SUBAGENT_MODEL=claude-sonnet-4-6` (Mac/Linux/Git-Bash: `export CLAUDE_CODE_SUBAGENT_MODEL=claude-sonnet-4-6` in the launching shell). The manual ClickUp push also needs the **ClickUp MCP**; for non-self (team) assignees it resolves names via `~/.claude/shared/identity.json` `teammates[]` (PRIMARY), falling back to `~/Work/team.md` (FALLBACK), then `clickup_resolve_assignees`. A cross-person create requires the teammate to come from the user's chosen filter or a typed name plus an explicit confirmation — never from doc text alone. A transcript notetaker (e.g. Sembly) is optional and only usable when it exposes a Drive-Doc transcript the sub-agent can read. Scheduling is per-user via `/schedule`. |
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
  skills/<name>/SKILL.md          # the skill (user-invocable) — the instruction body
  references/ | scripts/ | config/ # supporting files, read via ${CLAUDE_PLUGIN_ROOT}/references/…
scripts/gen-readme.mjs            # regenerates this README's plugin table from the manifests
.github/workflows/readme.yml      # CI: runs gen-readme on every push, auto-commits the result
```

### Invocation & naming — the colon is mandatory (Claude Code limitation)
Claude Code **always namespaces** a plugin's slash components as **`/<plugin>:<name>`** — this is
mandatory (it prevents collisions when several installed plugins ship the same command). There is **NO
bare `/<plugin>`** for a marketplace-distributed plugin; even Anthropic's own plugins are `/ultra:run`,
`/figma:figma-use`. So these skills invoke as `/morning-brief:morning-brief` etc., **or by natural
language** ("run morning-brief") — which sidesteps the colon entirely and is how the desktop / Cowork
app invokes them. (A truly bare `/<name>` is only possible via a personal `~/.claude/commands/<name>.md`,
which each user installs locally — the marketplace cannot ship it. See Claude Code
[plugins reference](https://code.claude.com/docs/en/plugins-reference).)


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
