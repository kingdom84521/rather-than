# Analysis lens (Layer 2)

Applied at analysis time (SKILL.md A2) over the dirty raw journal, NOT at
recording time. Recording (Layer 1) is judgment-free by design: a lost
record is unrecoverable, a bad analysis can be redone. Everything below is
about turning raw sentences into candidates worth asking about — the user
only ever sees survivors.

## First gate: is it even a decision?

Route every raw line through this table before any signal matching. Only
decisions become candidates; the rest leave the pipeline here:

| Kind | Definition | Negative test | Destination |
|---|---|---|---|
| **Decision** | Two or more defensible approaches; the user chose one | Phrasable as "X rather than Y" where **Y is not wrong** | Candidate — continue below |
| **Fact** | One correct answer, verifiable, wrong once stale | The alternative breaks or fails to compile | Not a candidate; belongs in whatever memory/knowledge system the machine runs, else drop |
| **State** | Time-bound world state that rots on its own | The same question tomorrow may answer differently | Same as fact, ideally with a verification date |
| **Rule** | A decision that no longer needs asking | Violating it is simply wrong; no receipts needed | Already CLAUDE.md/lint territory — hard-filtered below |

A single raw line can bind a fact to a decision ("Set has isSubsetOf" +
"use Set's own methods over a util lib when already holding a Set") —
split it: the fact exits, the decision continues.

If the machine runs a memory system, a semantic hit there for a decision
is **prior observation, never a capture blocker**: count it as an extra
Evidence line with its path in the receipts, proceed with capture, and
flag the memory entry for reclamation once the preference is confirmed
(MERGE.md). Only CLAUDE.md and enforced tooling block capture — they are
confirmed; memory is not.

## Signal sources — read the raw lines through all eight

### S1. Explicit demands (the user tells you)

The user specifies an approach where a simpler/more idiomatic alternative
exists, without a verifiable technical reason. Signals:

- Universal quantifiers: "always", "never", "一律", "都用", "不要再"
- Unprompted style directives mid-task ("while you're there, make those
  readonly")
- "we/我們" phrasing — weak team-scope evidence; note it, let the user
  classify
- A stated reason that is taste, not fact ("I find it clearer", "看起來比較
  乾淨") — that IS the preference; queue it with the taste as
  Inferred-Reason

### S2. Corrections (the user undoes you)

- The user rewrites or reverts functionally-correct code you produced —
  including edits you discover on re-reading a file you wrote earlier
- The same correction at a second site: by the second occurrence it is a
  pattern, queue it even if each instance alone looked incidental
- Repeated rejection of the same kind of suggestion ("不用", "算了", the
  user replaces your proposal with their own shape twice)

### S3. Codebase conventions (the repo tells you)

While reading repo files for any task, notice patterns that are consistent
across the codebase AND deviate from ecosystem defaults — e.g. every
service hand-rolls result objects where the ecosystem norm is exceptions;
all components use a naming shape the framework does not require. These
are unwritten team conventions in the wild — exactly what this skill
exists to surface.

- Queue with `Origin: codebase` and cite 2–3 witness files as Evidence
- Threshold: seen in ≥3 places with no counterexample in what you read.
  One file's quirk is not a convention.
- Never queue what a linter/formatter config in the repo already enforces
  — check first

### S4. Choices in the user's own new code

Libraries, utilities, or idioms the user picks when writing fresh code with
you ("use date-fns for this", picking RxJS operators a particular way).
One pick is noise; the second consistent pick is a candidate.

### S5. Passing mentions (revealed while talking about something else)

Preferences leak out in remarks that are not directed at you and not the
topic of the conversation: "上次就是被 barrel file 搞死", "那種一行塞三個
ternary 的碼我最怕", a war story about a past project, a complaint about a
library. These are the hardest to catch precisely because nothing is being
requested — treat any evaluative remark about code, tools, or practices as
a candidate, even mid-anecdote.

### S6. Selections among presented alternatives

When you present genuinely competing options and the user actively picks
one, the pick is a signal — unlike passive acceptance of your single
proposal, which remains blocked. One pick between two defensible options is
weak; queue on the second pick of the same *kind* (e.g. twice choosing the
more explicit variant, twice choosing the dependency-free variant). The
recurring dimension of choice, not the individual picks, is the preference.

### S7. Process and workflow (how they want you to work, not what code looks like)

Preferences are not only about code shape. Also watch how the user steers
your working style: commit granularity and message shape, tests before or
after, how much explanation they want, how large a change they tolerate per
step, whether they want you to refactor adjacent code or leave it alone.
These queue exactly like code-shape entries ("Prefer touching only the
files named in the task rather than opportunistic cleanup").

### S8. Domain and product conventions (what the product behaves like)

Not code shape — output shape. Unit carry rules ("16h displays as 2d"),
number formatting, empty-value rendering, terminology choices, ordering
conventions. These recur across features and are prime unwritten-team-
convention material. Discriminate from a one-off spec with the
**generalization test**: "this field shows 2d" names a target (spec — a
task, not a preference); "time units auto-carry" names a class
(convention — candidate). Ambiguous phrasing survives to the question;
the user settles it.

## Category checklist

When scanning, sweep these categories rather than waiting for something to
jump out — empirically, naming and readability carry the highest density of
convention feedback in code review, but every category below accumulates
preferences:

naming · formatting/layout · structure & control flow · types & API shape ·
error handling · state & immutability · dependencies & imports ·
comments/docs · tests · workflow (S7) · domain conventions (S8)

## Calibration (from implicit-feedback research)

- **Silence is not approval.** Implicit signals have no definitive
  negatives: code the user did not correct is evidence of nothing. Only
  actions — demands, corrections, picks, remarks — carry signal.
- **Correction frequency ≈ how much they care**, not how correct the rule
  is. Users correct what bothers them most. Use recurrence to order the
  batch (most-corrected first), never to skip confirmation.

## Hard filters (drop at analysis, but the raw line stays)

- The instruction is scoped to now: "for now", "先", "暫時", "this one"
- It is a task, not a rule (generalization test): a task names a target
  ("rename this to X"); a rule names a class of targets
- You proposed a single approach and the user merely accepted. Passive
  acceptance is not preference — but an active pick among competing
  alternatives is S6.
- The user was asking your opinion or exploring options
- A repo linter/formatter/compiler setting already enforces it, or
  CLAUDE.md already states it
- The harness/system prompt itself already instructs it (a system-level
  shadow — restating platform behavior as a preference adds nothing and
  drifts from the platform over time)

Filtered lines are not deleted — a plain task today may pair with the
same task next week into an S2/S4 recurrence. Everything that
pattern-matches any S1–S8 source and survives the filters becomes a
candidate.

## Verifiable reasons downgrade, not drop

A stated benchmark, compatibility constraint, known bug, or spec
requirement means the demand is fact-driven — usually not a preference.
But if the same fact-driven demand recurs across contexts where the fact
no longer applies, the residue is a preference; queue on the second
occurrence.

## Ladder every candidate (attribute → consequence)

A raw line states a preference at the attribute level; the candidate must
carry consequence-level reasoning before it reaches the user. For each
candidate, derive 1–3 competing "why" hypotheses from the raw lines'
contexts — abduction, not convenience: if only one explanation comes to
mind, actively look for a second before accepting the first. The
hypotheses become the reason question's options. A hypothesis that merely
rephrases the topic fails the one-why test ("why is that important?") and
is discarded. Values-level laddering (what the consequences ultimately
serve) belongs to promotion-time distillation, not here — one honest rung
is the tendency-stage bar.

Scope travels with the ladder: note WHICH contexts the raw lines came
from (their mandatory working-context clauses). The candidate's topic is
qualified to those contexts; claiming beyond them is a scope error.

## Candidate review (before asking)

Drop a candidate if:

- One-off after all (no recurrence, task-scoped in hindsight)
- Duplicates an existing entry or another candidate (merge; multiple raw
  lines = multiple Evidence lines on one candidate)
- Came from S3 but counterexamples exist in the repo

Then collapse survivors sharing a root cause into one question. Per batch,
at most ONE codebase-observation question — convention mining must never
dominate the user's attention.

## ignore.md semantics

Each ignore entry is a topic plus a one-sentence scope description.
Matching is semantic but conservative: skip capture only when the
situation clearly falls inside the described scope. A
plausible-but-uncertain match does NOT block — queue as normal. A wrong
silent drop loses a whole class of preferences with no trace.


## Elicitation mechanics (A3 detail)

### Receipts format

The question text quotes the source raw lines:

> On 7/25 while building the timesheet report you said "時間單位要自動
> 進位 (16h→2d)" — instead of showing raw hour totals. Track this as a
> preference?

### Defer

A deferred candidate is written to `<store>/deferred/<slug>.md`
with its complete analysis and source quotes — nothing is re-derived later:

```markdown
---
topic: Prefer <chosen> rather than <instead-of>, <scope qualifier>
deferred: <date>
defer-count: 1
---

## Sources
- <date>: <raw line, verbatim>

## Analysis
<category, competing reason hypotheses, recurrence notes, observed contexts>
```

During every analysis pass, check `deferred/` for topics related to the
new raw lines. A match means the topic is live again — re-ask it at the
top of the next batch with old AND new receipts while the user's context
is fresh; append the new sources and bump `defer-count`. At
`defer-count` ≥ 3 add to the question: "deferred twice already — `Never
track this` is a fine answer." Deferral is for indecision, not a polite
never.

### The one-why test

A reason that merely restates the topic, or cannot survive one round of
"why is that important?", is not a reason. Consequence level is the
tendency-stage bar; values-level laddering belongs to promotion-time
distillation.
