# Output style — so-what translation, verb-lint, and what makes the digest credible

The reader is in **another department** and never attended an automation call. They are silently asking: *"what does this mean for me / the company?"* — not "what tickets did you close". The whole difference between a credible digest and an ignored one lives in this file.

## The so-what template (every reader-facing line)

Each top-3 line should answer three things — outcome, who-outside-AUT, what-changed:

```
<outcome, plain language> — <who outside AUT it touches> — <what changed for them>
```

- **Outcome, not activity.** What is now true that wasn't, not what someone did.
- **Audience hook.** Name the department/person/process outside AUT that this affects, when there is one. If a line genuinely has no outside-AUT relevance, it probably isn't a top-3 for a *cross-dept* digest — demote it to the editor file.
- **Plain language.** No internal tool names without a gloss. A Finance reader shouldn't need a glossary.

**Before / after:**

- ❌ Worklog: *"Closed task: Fix HubSpot meeting-notes write-back not firing for client calls."*
- ✅ So-what: *"Client-call notes now sync to HubSpot automatically — Sales no longer re-enters them by hand — fixed a silent write-back failure."*

## Verb-lint (run on every reader-facing line)

`date_closed` means *a card was closed*, not *a product shipped*. Banned as the verb on cards whose name/list/so-what is research, review, or housekeeping:

- **Deny `shipped` / `delivered` / `launched` / `released`** when the underlying task is a `Research…`, `Investigate…`, `Spike…`, `Review…`, `Sync…`, `Evaluate…`, `Audit…`, or other non-shipping card. Use `researched`, `evaluated`, `reviewed`, `decided`, `unblocked` instead.
- **Also deny the multi-word "it's live now" phrasings** that slip past a single-word scan — `rolled out`, `went live`, `shipped to prod`, `in production` / `in production now`, `deployed to prod` / `deployed`, `GA'd`, `cut over` / `cutover` — on those same non-shipping cards. A two-word phrase is exactly as much of a false-shipment claim as `shipped`; lint the whole line text, not just the first verb.
- Keep `shipped/launched`/`rolled out`/`went live` only for tasks that genuinely put something into production / in front of users. (The Research/Investigate/Spike/Review/Sync/Evaluate/Audit/housekeeping carve-out is unchanged — those cards never get a ship-vocab verb regardless of phrasing.)
- An empty `<who outside AUT>` slot on a Closed line → demote it from the reader top-3 (it's internal plumbing; keep it in the editor file).

## Honest misses

Other departments trust a digest more when it admits friction. Surface at least one honest **blocked / slipped / carried-over** item when one exists — sourced from carried-over priorities or a named blocker in the notes. Frame it forward and owned ("X is blocked on Y; we're doing Z next"), and **never name another department as the cause** in the reader copy.

## No verification vocabulary

Never write "verified", "corroborated", "confirmed", or a 🟢/confidence badge. The same person closed the ticket, wrote the note, and spoke on the call — there is no independent witness, so a badge would overclaim. Say **"Closed this week (per ClickUp)"** and let the **citation** (the task URL / Doc section) be the proof. The human editor and the AUT-internal dry-run are the real trust layer.

## Tone & length

- Whole reader copy fits on one screen: TL;DR + 3 sections × ≤3 lines + a footer.
- Confident, plain, specific. No hedging cascades, no "we continued to work on…".
- If a week is thin, a 2-item section is honest; padding to 3 with filler is the failure mode.
