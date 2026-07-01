#!/usr/bin/env bash
# Doc-contract test for the ai-digest skill: asserts the load-bearing invariants
# (the ones the plan review proved are easy to get wrong) are present in SKILL.md /
# references, and that no secret is committed. Pure grep — makes no live API calls.
set -u
DIR="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$DIR/skills/ai-digest/SKILL.md"
CUP="$DIR/references/clickup-playbook.md"
OUT="$DIR/references/output-style.md"
GB="$DIR/references/geekbot-playbook.md"
PJ="$DIR/.claude-plugin/plugin.json"
fail=0
pass(){ echo "PASS: $1"; }
err(){ echo "FAIL: $1"; fail=1; }

# files exist
for f in "$SKILL" "$CUP" "$OUT" "$GB" "$PJ"; do
  [ -f "$f" ] && pass "exists: ${f#$DIR/}" || err "missing: ${f#$DIR/}"
done

# load-bearing ClickUp invariants
grep -qi "date_closed != null" "$CUP"            && pass "clickup: date_closed!=null post-filter"     || err "clickup: missing date_closed!=null post-filter"
grep -qi "subtasks=true" "$CUP"                   && pass "clickup: subtasks=true (not false)"          || err "clickup: must pull subtasks=true + roll-up"
grep -qi "under-count" "$CUP"                      && pass "clickup: notes subtasks=false under-counts"  || err "clickup: missing subtasks=false under-count warning"
grep -Eqi "suppress.*[Ss]tep|recurring step|Step [0-9/]" "$CUP" && pass "clickup: suppresses ^Step N recurring leaves" || err "clickup: missing Step-N suppression"
grep -qi "whole" "$CUP" && grep -qi "NEVER a keep/drop filter" "$CUP" && pass "clickup: whole-space scope, prefix=group key" || err "clickup: scoping rule (whole space / prefix not filter) missing"
grep -qi "paginate" "$CUP" || grep -qi "page until" "$CUP"          && pass "clickup: paginate-to-exhaustion" || err "clickup: missing pagination rule"
grep -qi "review" "$CUP" && grep -qi "null" "$CUP" && pass "clickup: documents review/null-date_closed leak" || err "clickup: missing review/null-date_closed trap note"
grep -qi "date_updated" "$CUP" && grep -qi "alone" "$CUP" && pass "clickup: in-progress not date_updated-alone" || err "clickup: in-progress must not key on date_updated alone"
grep -Eqi "reopen|re-close" "$CUP" && pass "clickup: reopen/re-close drift flagged" || err "clickup: missing reopen/re-close drift rule"

# honesty / anti-slop invariants
grep -qi "No verification vocabulary" "$SKILL"     && pass "skill: no-verification-vocabulary rule"      || err "skill: missing no-verification rule"
grep -qi "Cite everything" "$SKILL"                && pass "skill: cite-everything rule"                 || err "skill: missing cite-everything rule"
grep -qi "Never invent" "$SKILL"                   && pass "skill: never-invent rule"                    || err "skill: missing never-invent rule"
grep -qi "Read-only" "$SKILL"                       && pass "skill: read-only rule"                       || err "skill: missing read-only rule"
grep -Eqi "never auto-post|no auto-post|never .*auto-post" "$SKILL" && pass "skill: no auto-post"        || err "skill: missing no-auto-post rule"
grep -qi "Sonnet sub-agents only" "$SKILL"         && pass "skill: sonnet-only sub-agents"               || err "skill: missing sonnet-only rule"
grep -Eqi "verb-lint gate|second-pass gate|lines checked" "$SKILL" && pass "skill: verb-lint is an enforced gate (Step 6)" || err "skill: verb-lint must be an enforced gate, not advisory"
grep -Eqi "DEGRADED|notes unavailable|ClickUp-only" "$SKILL" && pass "skill: notes-missing -> loud ClickUp-only, not silent" || err "skill: missing notes-degraded guard"
grep -Eqi "Never .find|do not search|without searching the disk" "$SKILL" && pass "skill: no filesystem-search-for-skill-files rule" || err "skill: missing no-find rule (hang guard)"
grep -Eqi "paste.*inline|rules inline|inline into each sub-agent" "$SKILL" && pass "skill: sub-agents get rules inline (no file lookup)" || err "skill: sub-agents must get rules inline"
grep -Eqi "rules are COMPLETE in this prompt" "$SKILL" && pass "skill: sub-agent prompt declares rules complete (no file)" || err "skill: sub-agent prompt must declare rules complete"
grep -q "Do NOT mention any file path in a sub-agent" "$SKILL" && pass "skill: explicit no-file-path-in-subagent-prompt rule" || err "skill: must carry the explicit no-file-path-in-subagent-prompt rule"
grep -Eqi "error is not|backstop at 20|page ERRORS" "$SKILL" && pass "skill: pagination has an error/backstop cap" || err "skill: pagination needs an error/backstop cap"
grep -Eqi "carve-out" "$CUP" && pass "clickup: reopen needs date_created via Closed-pool get_task carve-out" || err "clickup: reopen-drift must note date_created carve-out"
grep -Eqi "do NOT call .get_task. across the open pools|get_task. across the open pools" "$SKILL" && pass "skill: no get_task across open pools (hang guard)" || err "skill: missing get_task open-pool guard"
grep -qi "so-what" "$OUT" && grep -qi "verb-lint" "$OUT" && pass "output: so-what + verb-lint defined"   || err "output: so-what/verb-lint missing"
grep -Eqi "shipped|delivered" "$OUT"               && pass "output: verb-lint bans shipped on non-ship cards" || err "output: verb-lint deny-list missing"

# packaging
grep -q '"name": "ai-digest"' "$PJ"               && pass "plugin.json: name=ai-digest"                 || err "plugin.json: name wrong"
grep -qi '"license": "MIT"' "$PJ"                  && pass "plugin.json: MIT license"                    || err "plugin.json: license missing"

# no secret leak in the plugin dir
if grep -rIl -E "Authorization: [A-Za-z0-9._-]{12,}|api[_-]?key[\"'\''[:space:]:=]+[A-Za-z0-9._-]{12,}|gho_[A-Za-z0-9]{20,}|pk_[A-Za-z0-9]{16,}" "$DIR" >/dev/null 2>&1; then
  err "secret-scan: a credential-looking string is committed in the plugin dir"
else
  pass "secret-scan: no credential-looking strings"
fi

# Geekbot invariants
grep -qi "cut -d= -f2-" "$GB" && grep -Eqi "never .*source|NEVER .source" "$GB" && pass "geekbot: key read as DATA (grep|cut), never sourced — RCE-safe" || err "geekbot: key must be read as data, NEVER sourced (RCE)"
grep -Eqi "RCE|remote code execution|would execute|run on read" "$GB" && pass "geekbot: playbook documents the source-as-RCE hazard" || err "geekbot: must explain why source is an RCE"
grep -Eqi "never in argv|-K -|stdin" "$GB" && pass "geekbot: secret via stdin not argv" || err "geekbot: key must not be in argv"
grep -Eqi "never originate|never creates a .Closed" "$GB" && pass "geekbot: never originates a theme / Closed" || err "geekbot: must never originate"
grep -qi "coverage < 0.6\|coverage.*0.6\|< 0.6" "$GB" && pass "geekbot: coverage floor 0.6" || err "geekbot: missing coverage floor"
grep -Eqi "MAX 100|limit 100|limit=100" "$GB" && pass "geekbot: limit<=100 (not 200)" || err "geekbot: limit must be <=100"
grep -qi "EXCLUDE" "$GB" && grep -qi "question" "$GB" && pass "geekbot: pinned question->bucket map w/ EXCLUDE" || err "geekbot: missing pinned bucket map"
grep -Eqi "OFF unless a key|OFF unless|Geekbot is .OFF|not configured" "$SKILL" && pass "skill: Geekbot OFF-by-default graceful" || err "skill: Geekbot must be OFF without a key"
grep -Eqi "From standups \(unverified\)" "$SKILL" && pass "skill: labelled From-standups lane" || err "skill: missing From-standups lane"
# Geekbot onboarding + local-key safety
grep -qi "Mode: --setup" "$SKILL" && pass "skill: interactive --setup onboarding mode" || err "skill: missing --setup onboarding mode"
grep -Eqi "never put in the repo|never committed|stays in a local file|outside any git repo|outside this repo" "$SKILL" && pass "skill: setup frames key as LOCAL / never-in-repo" || err "skill: setup must state key never goes to the repo"
grep -Eqi "do NOT paste the key here|never .*into .*chat|paste .*into (that|the) file|paste your key .*into" "$SKILL" && pass "skill: user pastes key INTO the file, never into chat" || err "skill: key must go into the file, not the chat"
grep -Eqi "Create the key file FOR them|create an empty.*key file|creates? .*~/.geekbot/env" "$SKILL" && pass "skill: setup CREATES the key file for the user (placeholder + chmod 600)" || err "skill: setup must create the key file for the user"
grep -Eqi "BROKEN" "$SKILL" && grep -Eqi "auth failed|configured but|loud-fail|never silently downgrade" "$SKILL" && pass "skill: OFF vs BROKEN loud-fail (dead key warns, not silently dropped)" || err "skill: must distinguish OFF from BROKEN (loud-fail on dead key)"
grep -qi "user_id" "$GB" && grep -Eqi "OMITTED|omit .user_id|all members|all participants" "$GB" && pass "geekbot: omit user_id => ALL team members in one call" || err "geekbot: must fetch all members"
grep -qi "never committed\|LOCAL ONLY\|outside this repo\|outside .* repo" "$GB" && pass "geekbot-playbook: key is local-only / never committed" || err "geekbot-playbook: must state key is local-only"
grep -q -- "--setup" "$SKILL" && pass "skill: --setup advertised (flags table)" || err "skill: --setup missing"
# SKILL layout: skills/ai-digest/SKILL.md (user-invocable). Invoked /ai-digest:ai-digest (namespaced) or via natural language; no bare command exists for a marketplace plugin.
test -f "$DIR/skills/ai-digest/SKILL.md" && [ ! -f "$DIR/SKILL.md" ] && [ ! -d "$DIR/commands" ] && pass "layout: skill (skills/ai-digest/SKILL.md, no root SKILL.md or commands/)" || err "layout: must be skills/ai-digest/SKILL.md (no root SKILL.md or commands/)"

# interactive first-run UX (Andy feedback): setup OFFER, period confirm, connector onboarding
grep -q "Step 1b" "$SKILL" && grep -qi "AskUserQuestion" "$SKILL" && pass "skill: Step 1b first-run setup OFFER (interactive)" || err "skill: missing Step 1b interactive setup OFFER"
grep -Eqi "Connector setup guidance" "$SKILL" && grep -Eqi "never connects them itself|walks any machine through connecting" "$SKILL" && pass "skill: guided connector onboarding (ClickUp/Drive/Geekbot)" || err "skill: missing guided connector-onboarding"
grep -Eqi "Confirm the period" "$SKILL" && grep -Eqi "Reporting week" "$SKILL" && pass "skill: bare-run confirms the reporting week (shows dates)" || err "skill: must confirm the period on a bare run"
grep -Eqi "interactive run AND when .--yes|headless|claude -p" "$SKILL" && pass "skill: interactive checkpoints skipped when headless / --yes" || err "skill: must skip interactive checkpoints headless"
grep -q -- "--non-interactive" "$SKILL" && grep -q -- "--yes" "$SKILL" && pass "skill: --yes/--non-interactive flag documented" || err "skill: missing --yes/--non-interactive flag"

# output lands in cwd, not a hidden home dir (Andy feedback)
grep -Eqi "current working directory" "$SKILL" && grep -F -- "--out" "$SKILL" >/dev/null && pass "skill: editor file written to cwd by default (--out override)" || err "skill: output must default to cwd"
grep -F "ai-digest-<YYYY-Www>" "$SKILL" >/dev/null && pass "skill: default editor filename ./ai-digest-<week>.md" || err "skill: missing cwd default filename"
grep -Eqi "cross-platform" "$SKILL" && grep -Eqi "Windows" "$SKILL" && pass "skill: cross-platform output path (no macOS-only ~/stat -f)" || err "skill: output path must be cross-platform"

# ClickUp date_closed capability probe + date-blind fallback (discovered in Andy's run)
grep -Eqi "date_closed.{0,3}capability" "$SKILL" && grep -Eqi "date-blind" "$SKILL" && pass "skill: preflight probes date_closed capability (date-blind path)" || err "skill: must probe date_closed capability"
grep -Eqi "date-blind fallback" "$CUP" && grep -Eqi "per ClickUp status, notes-dated" "$CUP" && pass "clickup: designed date-blind Closed-pool fallback (status+notes)" || err "clickup: missing date-blind fallback"
# date-blind branch is WIRED into the executable Step-3 gather prompt (not just the playbook)
grep -F "[OK date-blind]" "$SKILL" >/dev/null && grep -Eqi "per ClickUp status, notes-dated" "$SKILL" && pass "skill: Step-3 ClickUp sub-agent has the date-blind branch inline (reachable)" || err "skill: date-blind fallback not wired into Step-3 sub-agent prompt"
# interactive checkpoints are headless-SAFE by default (don't hang automation)
grep -Eqi "default to NON-interactive|unsure.*non-interactive|non-TTY" "$SKILL" && pass "skill: unsure-interactivity defaults to non-interactive (no hang)" || err "skill: must default to non-interactive when unsure"
grep -Eqi "no-op under .--yes|setup needs an interactive session" "$SKILL" && pass "skill: --setup is a no-op under --yes/headless" || err "skill: --setup must not prompt headless"
# during-gather heartbeat + bounded retry (the '20 min of silence' half of complaint #1)
grep -Eqi "Heartbeat" "$SKILL" && grep -Eqi "as it returns|as each sub-agent returns" "$SKILL" && pass "skill: during-gather heartbeat (streams sub-agent summaries)" || err "skill: missing during-gather heartbeat"
grep -Eqi "Bounded retry" "$SKILL" && pass "skill: bounded ClickUp retry (no serial re-wait / silent-20-min trap)" || err "skill: missing bounded-retry on ClickUp gather"

# ultra-xl review must-fixes (PR #4)
# (1) the cwd digest output is gitignored (never commit internal pools / standup data)
GI="$DIR/../../.gitignore"
grep -Eq "ai-digest-\*\.md|ai-digest-runs/" "$GI" 2>/dev/null && pass "repo .gitignore covers ai-digest cwd output (no committed dept data)" || err "repo .gitignore must ignore ai-digest-*.md / ai-digest-runs/"
# (2) probe is non-empty-guarded: a zero-row / quiet week is NOT date-blind; ERROR != date-blind
grep -Eqi "NON-EMPTY result|zero-row probe is NOT date-blind" "$SKILL" && grep -Eqi "ZERO rows" "$SKILL" && pass "skill: date_closed probe non-empty guard (quiet week != date-blind)" || err "skill: probe must not call a zero-row window date-blind"
grep -Eqi "error is NOT date-blind|an error is NOT date-blind" "$SKILL" && pass "skill: probe ERROR != date-blind (retry then BROKEN)" || err "skill: probe must split ERROR from date-blind"
# (3) date-blind Closed is notes-mention ONLY (no forbidden get_task for comments) + re-affirms roll-up/dedup
grep -Eqi "notes-mention ONLY" "$SKILL" && grep -Eqi "notes-mention ONLY" "$CUP" && pass "skill+clickup: date-blind Closed is notes-mention only (no comment/get_task)" || err "date-blind Closed must be notes-mention only"
grep -Eqi "roll up closed child|Roll up \+ de-dup" "$CUP" && grep -Eqi "roll up closed child subtasks to their parent and de-dup" "$SKILL" && pass "skill+clickup: date-blind branch re-affirms roll-up/dedup/^Step suppression" || err "date-blind branch must re-affirm roll-up/dedup"
# (4) no stale 'source it' contradicting the RCE fix
grep -Eqi "source it, never print" "$GB" && err "geekbot-playbook: stale 'source it' example contradicts the RCE fix" || pass "geekbot-playbook: no stale 'source it' (RCE-consistent everywhere)"
echo
[ "$fail" -eq 0 ] && { echo "ALL CONTRACT CHECKS PASSED"; exit 0; } || { echo "CONTRACT CHECKS FAILED"; exit 1; }
