# Consolidation rules

## Inputs

All `journal/*.md` in the root. Two classes:

- `confirmed` entries — always processed
- unconsumed `## candidate /` blocks — consumed through A3 elicitation
  (strength order) like any candidates, whatever session wrote them.
- unanalyzed raw lines — processed only when **orphaned**: the owning
  session's alive marker (`.state/sessions/<sid>.alive`) is missing or
  >30 minutes stale. Journal age is irrelevant. Run the A2 lens over them,
  write surviving candidates back as blocks, and take them through A3.
  Raw lines of live sessions belong to those sessions; leave them.

## Conflict detection

1. Group deltas by slug. Contradictory operations on one slug — DELETE
   alongside EXCEPT, or two excepts that cannot both hold — are conflicts.
2. **Cross-slug pass:** compare every incoming delta against the full index
   semantically. Two entries under different slugs can still contradict
   (e.g. `prefer-composition` vs `inheritance-for-widgets`). Same-slug
   grouping alone misses these.

## Conflict classification

**Simple** — exactly two competing outcomes, no restructuring plausible.
Present both directly in the batch AskUserQuestion. No debate.

**Contested** — 3+ stances; or the same slug keeps attracting contradictory
excepts (a framing smell); or the conflict spans slugs. Invoke the
`multi-debate` skill:

- One stance per competing delta; add stance R (restructure) on a framing
  smell
- Context: the affected `prefer/` files + the journal deltas
- `Resolution: judge` — always. Preference decisions are never delegated
  to agent consensus or voting.
- Map returned proposals to one AskUserQuestion entry: label = Label,
  description = Argument + Cost, plus `Keep as-is`
- `Converged: true` → downgrade to a single confirm

## Apply

| Op | Action |
|---|---|
| NEW | Create `prefer/<slug>.md`; merge instead if a semantically identical file exists |
| EVIDENCE | Append to `## Evidence` |
| EXCEPT | Append to `## Except` with its nested Reason |
| DELETE | Remove the file |

Every edit is localized to one file. Never regenerate the store wholesale —
iterative full rewrites erode detail (context collapse) and trade insight
for brevity.

## Refine

- Duplicate files: merge into the more specific one; keep the more specific
  Reason, concatenate Evidence, delete the other, rebuild index.
- 3+ Except clauses on one entry: the topic is too broad. Narrow the topic
  so the recorded evidence coexists with at most 1–2 excepts. If the right
  narrowing is not obvious, that is a Contested conflict — debate it.
- Stale entries (newest Evidence months old, subject gone from the
  codebase): surface to the user, ask before deleting. Never delete
  unprompted.
- Dormant entries: aggregate the root's usage.log; an entry with zero
  applied/excepted/overridden events in 60 days is dormant. Flag it with
  the two possible readings — the preference stopped mattering (project
  moved on), or the implicit path keeps missing it (a detection bug worth
  reporting). Ask the user which; never delete unprompted.
- Category backfill: entries whose frontmatter lacks `category` are
  invisible to category-first scanning. Assign one from the DETECTION
  checklist during every audit; the index rebuild moves them out of
  `uncategorized`.
- Memory reclamation (only where the machine runs a memory system —
  auto-memory or a user-maintained store): after a preference is confirmed
  here or promoted to a rule, semantically equivalent memory entries are
  shadows. List them with paths and ask the user before deleting; never
  reclaim unprompted, never treat a memory hit as a reason to skip
  capture — an unconfirmed memory entry is prior observation (extra
  Evidence), not a confirmed rule.
- Do not compress for brevity. A growing store is expected; organize it.

## Calibration (from elicitation.log)

Aggregate `<store>/.state/elicitation.log` per
origin. For any origin with ≥10 samples and acceptance rate
(personal+team over total) below 30%, propose a tightening in the batch
question (e.g. "S5 acceptance is 2/11 — require a second occurrence
before queueing S5?"). On approval, write the rule to
`.state/calibration.md` (one line per origin); A1 reads it as an
override. Never tighten without asking; never loosen automatically.

## Distillation note

If the audit leaves three or more active entries in one DETECTION.md
category, you may state that fact in one sentence. Nothing more: do not
read references/PROMOTE.md, do not describe the promotion procedure, and
never start Mode D without an explicit user command.

## Deferred candidates

`deferred/` is not consolidated. Consolidation deletes processed journals,
but deferred files carry their own source quotes precisely so they survive
journal deletion. During refine, report deferred files whose `deferred`
date is >90 days old with no source additions — ask the user whether to
drop them; never delete unprompted.

## Finish

Rebuild the index and release the locks — also on failure. Delete only
fully drained journals: raw lines analyzed (end marker present), zero
`## candidate /` blocks remaining, confirmed blocks applied. A journal
holding unconsumed candidates stays; entries written while consolidating
belong to the next pass.
