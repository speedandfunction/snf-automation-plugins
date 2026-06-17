#!/usr/bin/env bash
# Doc-contract test for the ai-digest skill: asserts the load-bearing invariants
# (the ones the plan review proved are easy to get wrong) are present in SKILL.md /
# references, and that no secret is committed. Pure grep — makes no live API calls.
set -u
DIR="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$DIR/skills/ai-digest/SKILL.md"
CUP="$DIR/skills/ai-digest/references/clickup-playbook.md"
OUT="$DIR/skills/ai-digest/references/output-style.md"
PJ="$DIR/.claude-plugin/plugin.json"
fail=0
pass(){ echo "PASS: $1"; }
err(){ echo "FAIL: $1"; fail=1; }

# files exist
for f in "$SKILL" "$CUP" "$OUT" "$PJ" "$DIR/commands/ai-digest.md"; do
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

echo
[ "$fail" -eq 0 ] && { echo "ALL CONTRACT CHECKS PASSED"; exit 0; } || { echo "CONTRACT CHECKS FAILED"; exit 1; }
