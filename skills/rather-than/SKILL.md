---
name: rather-than
description: Capture and apply preference-driven coding decisions as tendencies (warnings, not rules), with a gated promotion path from tendency to enforced rule. Use when the user asks for an approach that carries a preference component — not the simplest form, not the most efficient form, or a specific style demanded without a stated technical reason — to confirm whether it is a personal preference or an unwritten team convention and record it as a Topic/Reason/Except entry. Also use to consolidate journal entries reported at session start, or when the user wants to view, edit, or delete tracked preferences.
allowed-tools: Read, Write, Edit, Glob, Bash, Task, AskUserQuestion
---

# rather-than

Track why the user writes code a particular way, so later sessions do not
re-litigate settled decisions.

## Store layout

Two scopes. The classification question decides which one an entry lands in.

| Scope | Root | Committed to git |
|---|---|---|
| personal | `<store>/` | no |
| team (local staging) | `<store>/team/<repo-key>/` | no |
| project (published) | `<repo>/.rather-than/` | yes (gitignore `index.md`) |

`<store>` is the personal store root, resolved as `$RATHER_THAN_HOME` when set, else an
existing `~/.claude/rather-than`, else `${XDG_DATA_HOME:-~/.local/share}/rather-than`. The
published root is `<repo>/.rather-than/`, except in a repo that already carries the legacy
`<repo>/.claude/rather-than/`. Both are agent-independent: the same store serves every
agent you drive. The injected session context states every resolved path — use those, never
derive them.

`<repo-key>` is derived from the repo (git-root directory name plus a short
path hash); the injected session context states the resolved path — use that,
do not derive it yourself.

Team-classified entries are **written to local staging only**. The project
root is read-only for capture: its entries (committed by teammates) are
injected and applied like any others, but new team entries land in staging
until explicitly published (see B7). This keeps experimental rules out of
git until the user opts in.

Each root contains:

- `prefer/<slug>.md` — one preference per file. **Source of truth.**
- `index.md` — generated topic list, injected into context every turn by the
  companion hook. Never edit by hand; rebuild it instead.
- `journal/<sid>.md` — **personal root only**. This session's raw event
  log (dirty, one sentence per event) plus confirmed blocks awaiting
  consolidation. The hook creates it with a provenance header naming the
  session's repo and team staging root — that header, not the file's
  location, is how consolidation routes team-scope blocks.
- `ignore.md` — topics the user has opted out of.

Execution state — hook bookkeeping, per-root usage logs, the consolidation lock —
lives in one place outside the roots, at `<store>/.state/`, so an
agent or plugin update cannot take it with it. The injected session context names
every state dir; use those paths.

`<sid>` comes from the injected session context. If absent, generate one with
`date +%Y%m%dT%H%M%S`-`$RANDOM` and reuse it for the whole session.

Skill scripts live in this skill's `scripts/` directory. Rebuild the index
with `scripts/rebuild-index.sh <root>` after any change under `prefer/`.

### Write rules

- Never write to `prefer/` outside Mode B or Mode C. Every capture goes to
  the journal first.
- Never write to the project root except in the B7 publish step or an
  explicit Mode C request. Team captures always target local staging.
- One journal file per session, append-only. Two sessions modifying the same
  preference produce two visible deltas instead of one silent overwrite.
- `index.md` is derived. Rebuild it; never hand-edit it.
- There is no supersede state. A preference is either narrowed with an
  `Except` or deleted outright. Nothing is kept as a tombstone.

## Applying tendencies

**Entries are tendencies, not rules.** They are warning-level: prefer
following them, but they never block, never lecture, and yield to
correctness, to readability in context, and to their own Excepts. The
promotion path in `references/PROMOTE.md` is how a tendency becomes an
actual rule; until then, treat it as a documented lean.

The injected context carries the index for both scopes — a topic line and a
slug per entry. Treat it as a table of contents.

**Implicit path (you are writing code):** the index is grouped by
category — first pick the categories the current work touches (writing a
service touches error handling, naming, types; a template touches
formatting, structure), then scan those sections' entries — **plus the `uncategorized` section,
always** (an entry without a category is invisible to category-first
scanning; sweeping uncategorized is what keeps it alive until an audit
backfills its category); read `<root>/prefer/<slug>.md`
for each relevant entry before writing, not after. The Except clauses live
in the file — applying a tendency inside its own exception is worse than
not knowing it. Entries flagged `[N except]` must be read before use.
Follow the tendency unless it conflicts with correctness, local
readability, or a recorded Except; when you deviate, say so in one sentence
— do not ask permission.

**Stay inside `observed-in`.** A preference is trusted evidence only in
the contexts it was observed in; the current work falling outside them is
a novel scenario, and stated preferences are observations of intent, not
the intent itself. Apply it there if it still seems right, but record a
raw line noting the first extension into the new context — confirmation
grows `observed-in`; pushback becomes an Except. Never silently treat a
scoped tendency as universal.

**Explicit path (the user asks for something a tendency leans against):**
never block, never moralize. Infer intent, act, and queue accordingly.
**Scale the mention to the evidence**: violating a heavily-used entry
(many applied events, several confirmed Evidence lines) earns a mention
with receipts — when it was confirmed, how often it has applied, the
recorded reason — so the user overrides informed; violating a fresh
inferred entry earns one clause. Same compliance either way:

| Intent signal | Action |
|---|---|
| One-off tone ("先", "這邊", "this once") | Comply; mention the tendency in one clause; record nothing |
| A situation the tendency did not anticipate | Comply; record the raw line noting it conflicts with the entry |
| Repudiation ("以後都", "不要再", overrides a past stance) | Comply; record the raw line marking it a repudiation; analysis turns it into a DELETE candidate |
| Unclear | Comply; queue; the batch question resolves it. **Always comply first — a tendency has no standing to block.** |

**Usage log:** whenever you follow, deviate from, or hit an Except of an
entry while producing code, append one line to that root's usage log under
the skill state dir (paths given in the injected context):

```
<YYYY-MM-DD> <slug> applied
<YYYY-MM-DD> <slug> excepted match=<which except>
<YYYY-MM-DD> <slug> overridden reason=<one-token-reason>
```

One bash append per event, best-effort — a missed line only makes
promotion more conservative. These counts feed the promotion gates
(PROMOTE.md); `applied` is weak evidence (relevance, not endorsement),
user-confirmed Evidence is strong evidence, and a high overridden ratio is
counter-evidence.

## Mode selection

- Injected context reports journal entries pending consolidation, or the
  user asks to tidy up preferences → **Mode B**
- User wants to view, edit, or delete entries → **Mode C**
- User explicitly commands distillation/promotion ("promote", "distill",
  "整理成規則") → **Mode D** (`references/PROMOTE.md`)
- User explicitly commands a history bootstrap ("bootstrap", "挖歷史") →
  **Mode E** (`references/BOOTSTRAP.md`); command-only, like Mode D
- Otherwise, a preference signal was detected → **Mode A**

---

## Mode A — capture (two layers)

Layer 1 records dumbly every turn; Layer 2 analyzes in batches. The
reliability bet: remembering to write one sentence is far more robust than
running an eight-way classification under task pressure. The journal is
deliberately dirty — plain task requests included — because recording
misses are unrecoverable while analysis mistakes can be retried.

### A1. Record (every turn, no judgment)

Whenever the user steers anything — or you notice a codebase pattern —
append ONE natural-language sentence to `journal/<sid>.md` — **always in
English**, regardless of the conversation language. The journal is read by
the analysis pass far more often than by humans; translate the user's
words into English and keep only technical terms or truly untranslatable
phrases verbatim. No fields, no structure; the grammar carries everything.
Archetype (not a rigid template):

> User decided to do <something> instead of <something>, because <reason>.

Let the verb carry the event type, and capture the instead-of side WHILE
IT STILL EXISTS — your overwritten draft, the current behavior, the
unpicked option all evaporate after this turn:

```
- 2026-07-27: User asked for time units to auto-carry (16h→2d) instead of raw hour totals, while we were building the timesheet report.
- 2026-07-27: User corrected my `type` alias back to an `interface`, second time this week.
- 2026-07-27: User complained in passing that barrel files wrecked a past project.
- 2026-07-27: User picked the explicit-generics variant over the inferred one when I offered both.
- 2026-07-27: User told me to fix the pagination bug in mail-list.
- 2026-07-27: Noticed all four services hand-roll Result objects instead of throwing, ecosystem default is exceptions.
```

Record: directives (including plain tasks), corrections of your output,
evaluative remarks (complaints, praise, war stories), picks among options
you offered, process steering, and your own codebase observations. Include
the stated reason when one was given.

**Retrospective mentions count.** A decision surfaced indirectly — a
wrap-up summary, a retrospective, any in-conversation list of "choices
made this session" — is a recordable event if it is not already in the
journal. The source being a summary rather than the original utterance
does not matter; date the raw line by when the decision originally
happened if stated, and note the indirect source in the sentence.

**Working context is mandatory, not flavor.** Every raw line names what
was being worked on when the event happened ("while building the timesheet
report", "in the compose component's error path") — this is the raw
material all later scope reasoning stands on; a context-free line cannot
support a scope-qualified preference. Skip only pure information questions
with no evaluative content.

Recording never interrupts the task and is never mentioned to the user.

### A2. Analyze (batch, full judgment)

Trigger at whichever comes first: a break-point signal (commit, "這樣就
好", task switch); ≥8 unanalyzed raw lines; session start reports dead
sessions' unanalyzed journals. Never mid-task.

Read the raw lines since the last analysis marker and apply the analysis
lens in `references/DETECTION.md`: the S1–S8 signal taxonomy, the hard
filters (task-not-rule, scoped-to-now, lint-enforced, passive acceptance,
already-in-CLAUDE.md), the generalization test, recurrence pairing, and
deduplication against the injected index. Extraction yields zero or more
candidates; the raw lines that yielded nothing stay in the journal
untouched — they may pair with future lines (a second occurrence turns
noise into signal).

**Every extracted candidate is written back to the journal** as a
first-class block — analysis work is never held only in your head, where a
context switch or crash loses it:

```markdown
## candidate / <slug>
- Topic: Prefer <chosen> rather than <instead-of>, <scope qualifier>
- Category: <checklist category>
- Strength: <evidence count> evidence; <quantifier|repeat|single> signal
- Receipts:
  - <date>: <raw line, verbatim>
- Hypotheses: <competing consequence-level reasons>
```

Then append an analysis marker after the last raw line read:

```
<!-- analyzed 2026-07-27T15:02, 2 candidates -->
```

Later analyses read only raw lines below the newest marker; candidate
blocks persist until A3 consumes them. Mode B may re-read everything.

### A3. Ask — always with receipts

Every preference question carries its receipts — date, what was said
(verbatim or near), what it was instead of, what was being worked on. A
question you cannot attach receipts to is a question you are not ready to
ask. This applies here, to Mode B conflicts, and to deferred re-asks.

A3 consumes the journal's unconsumed `## candidate /` blocks — including
blocks left by earlier sessions. One `AskUserQuestion` call, up to four
questions, one per candidate. Order: deferred re-asks first, then by
Strength (evidence count, then quantifier force) — **never by recency**; a
strong candidate must not lose its slot to a fresher weak one. Candidates
beyond four stay in the journal, safe, for the next wave:

- `Personal preference` — personal scope
- `Team convention` — team scope, kept in local staging
- `Defer` — keep the full analysis; ask again when the topic next comes
  up live
- `Never track this` — append the topic to `ignore.md`

**Answers bind; elaborations queue.** The user's direct answer to what
was asked is authoritative. Everything else in their reply — war stories,
additional preferences, out-of-scope thoughts — is new raw material:
record it, split it atomically, route it through the DETECTION gate like
any signal. Never transcribe it into the entry being confirmed. If it
contradicts recorded Evidence, surface the tension instead of silently
agreeing. Full discipline in `references/REVIEW.md`.

The reason question is a laddering probe: offer 1–3 competing
consequence-level hypotheses (never a topic restatement), or the direct
probe when none derive. Unconfirmed reasons are `confidence: inferred`.
Full elicitation mechanics — receipts format, defer files and re-ask
triggers, defer-count escalation, the one-why test — in
`references/DETECTION.md`.

### A4. Promote answers

Delete each consumed `## candidate /` block (its outcome now lives as a
confirmed block, a deferred file, or an ignore entry; a skipped
candidate's raw lines remain for future pairing). Append each accepted
candidate as a structured confirmed block to the same session journal the
raw lines live in. The `Scope` field plus the
journal's provenance header route it at consolidation — nothing moves
between files. Mode B consumes these mechanically:

```markdown
## confirmed / <NEW|EVIDENCE|EXCEPT|DELETE> / <slug>
- Topic: Prefer <chosen> rather than <instead-of>
- Scope: <personal|team>
- Category: <DETECTION.md checklist category>
- Reason: <confirmed or inferred>
- Evidence: <date> <site>
```

Append never-track topics to `ignore.md` as
`- <slug>: <one-sentence scope description>`.

Then log every answer — including skips — to
`<store>/.state/elicitation.log`, one line each:

```
<YYYY-MM-DD> <origin> <slug> <personal|team|defer|never>
```

Skips and nevers are labeled negatives: they are what lets the audit
measure each signal source's precision and tighten noisy sources.
`prefer/` is still untouched at this point.

### A5. Apply

Apply the confirmed preferences to the code under discussion immediately.
Do not wait for consolidation.

---

## Mode B — consolidate

Triggered when the injected context reports confirmed or orphaned journal
entries, or on request. Full rules in `references/MERGE.md`.

### B1. Lock

Acquire the lock for every root you will write — personal, plus each team
staging root named by the journals' provenance headers:
`scripts/consolidate-lock.sh acquire <state-dir-for-root>` (the current
repo's state dirs are in the injected context; a foreign staging root's
state dir follows the same pattern, `team-<key>` beside them). If a lock
fails, skip that root's blocks this pass — another
session is consolidating — skip, do nothing, do not wait. Release with
`scripts/consolidate-lock.sh release <state-dir-for-root>` when done,
including on failure.

### B2. Read

Journals live only in the personal root. Read every
`<store>/journal/*.md` and the `prefer/` files their blocks
reference. Each journal's provenance header names the team staging root
its team-scope blocks belong to — route by that header, never by the
current session's repo (an orphan journal may come from a different
repo).

- `confirmed` blocks — always processed.
- unanalyzed raw lines and unconsumed candidate blocks — only when
  **orphaned**: the owning session's alive marker
  (`.state/sessions/<sid>.alive`, touched by the hook every turn) is
  missing or >30 minutes stale. Journal age is irrelevant — a session that
  ended minutes ago is fair game, which is exactly when the user's memory
  of the material is freshest. Run the A2 analysis lens over them and
  take survivors through A3 before applying. Fresh raw lines belong to
  their own session; leave them.

### Review gate — one entry at a time, before every `prefer/` write

Nothing is written to `prefer/` unconfirmed. For each pending change:
translate it into `<store>/REVIEW.md` (overwriting — the
file always holds exactly one entry), get one confirmation (寫入 / 需要
修改 / 暫緩 / 取消 review), write on approval, then move to the next.
Format and elaboration discipline in `references/REVIEW.md`: gist-first
bottom line, positive and negative behavior examples, plain-language
scope and Except boundaries (the two danger zones), verbatim receipts
last. Feedback on a draft goes through answers-bind / elaborations-queue
like any elicitation reply.

### B3–B6. Resolve, apply, refine, finish

Full procedure in `references/MERGE.md`: conflict detection (same-slug +
cross-slug semantic pass), simple-vs-contested classification (contested →
`multi-debate`, `Resolution: judge`, always with receipts), the op table
(NEW/EVIDENCE/EXCEPT/DELETE), refine rules (duplicates, except bloat,
dormant and stale entries, calibration from elicitation.log), then rebuild
indexes, release the locks, and B7 below. Delete only fully drained
journals: raw lines analyzed, zero `## candidate /` blocks remaining,
confirmed blocks applied — candidates must never die with the journal
that carries them.

---

## Mode C — view and maintain

**View** → answer from the injected index. Read individual files only for
entries the user actually asked about. Do not recite the whole store.

**Delete** → confirm the scope, remove `prefer/<slug>.md`, rebuild the
index. Deletion means deletion; do not rewrite the entry as a former
preference.

**Review** (user asks to review preferences) → list all entries from the
injected index, numbered and grouped by category, in chat (a plain list —
AskUserQuestion cannot hold a whole store). The user names one; translate
that single entry into `<store>/REVIEW.md` per
`references/REVIEW.md` — read-only, no writes. Edits or deletions happen
only if the user then asks.

**Clean** (user asks to clean/scan the store) → run
`scripts/hygiene-score.sh <root> <state-dir-for-root>` for each root
(results cached in `<state-dir>/hygiene.tsv`; unchanged entries cost
nothing to rescore). List only entries scoring ≥30, each with its score
and the two largest contributing factors. The user picks one; show its
translation plus the score breakdown, then offer remedies mapped to the
factors — missing category → backfill; `inferred` → confirm the reason
now (with receipts); except bloat → narrow the topic; dormancy → ask
whether the preference expired or the implicit path keeps missing it (a
detection bug worth reporting); delete → delete. Every remedy runs
through the existing machinery; nothing is auto-fixed.

**Publish / unpublish** → on request, move an entry between team local
staging and the project root (copy, rebuild both indexes, delete the
source copy). Publishing outside B7 happens only when the user asks.

**Edit** → edit the file directly. This is the one case where writing to
`prefer/` outside consolidation is allowed. Rebuild the index if `topic`,
`confidence`, or the except count changed.

---

## Mode D — distill and promote

**Runs ONLY on an explicit user command.** Never triggered by audits,
entry counts, or your own judgment — and `references/PROMOTE.md` must not
be read into context until that command is given. Mentioning that Mode D
exists is allowed; reading or executing any part of it is not.

Full procedure and gate thresholds in `references/PROMOTE.md`. Summary:
cluster related entries, induce the single principle that explains every
Evidence line AND every Except across the cluster, write it as a candidate,
then run the five promotion gates (support, exception closure,
counterexample search, mechanical-enforceability triage, adversarial
debate). Only a candidate that clears all five reaches the user for final
approval. Promotion output is a lint/tsconfig change when mechanically
expressible, otherwise a CLAUDE.md rule; promoted source entries are
deleted. Rejected candidates change nothing.

---

## Mode E — bootstrap from history

**Runs ONLY on an explicit user command**, like Mode D. Mines two existing
evidence stores — GitLab MR review discussions (via `glab`) and the git
log's correction-shaped commits — into ordinary raw journal lines,
then hands off to the normal batch elicitation (A4) in waves. Nothing
reaches `prefer/` without the same confirmation every live capture gets.
Procedure in `references/BOOTSTRAP.md` (do not read it before the
command).

---

## Preference file format

```markdown
---
topic: Prefer <chosen approach> rather than <rejected approach>, <scope qualifier>
scope: team
confidence: confirmed
category: <one of the DETECTION.md checklist categories>
observed-in: [<context where evidence occurred>, <another context>]
created: 2026-07-22
---

## Reason
<the reason the user confirmed, or the inference if confidence is inferred>

## Except
- <situation where the rule does not apply>
  - Reason: <why the exception exists>

## Evidence
- <date> <file>:<line>
```

Slugs are kebab-case, derived from the chosen approach, under 40 characters.
If a proposed slug already exists, that is a dedup miss — go back to A2.

**The topic claims no more than `observed-in` covers.** Evidence from
report displays yields "Prefer auto-carried time units rather than raw
hour totals, in user-facing displays" — never the bare universal.
Widening a topic beyond its observed contexts is generalization, and
generalization is promotion's job (PROMOTE.md Gate 3 exists to validate
exactly that); a tendency keeps its qualifier for its whole life.

---

## Do not

- Record anything a linter, formatter, or compiler setting already enforces,
  or anything already stated as a rule in CLAUDE.md (user or project level).
  Those are rules; duplicating them as tendencies is noise.
- Record one-off instructions ("just hardcode it for now", "comment that
  out temporarily").
- Ask more than once per turn. If the user corrects three things in a row,
  collect them and ask once.
- Confuse an instruction with a preference. "Rename this function to X" is
  a task. "Function names always start with a verb" is a preference.
- Record something you proposed that the user merely did not object to.
  They must have explicitly chosen it or explicitly asked for it.
