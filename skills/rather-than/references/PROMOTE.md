# Distillation and promotion (Mode D)

A tendency graduates into a rule only through this procedure. The stance is
deliberately conservative: entries mined from observation are hypotheses,
and specification-mining practice shows most candidates do not survive
vetting. The cost asymmetry justifies it — a late promotion delays a rule
by weeks at near-zero behavioral cost, while a wrong promotion executes
errors everywhere the rule reaches and is expensive to walk back.

## Trigger

Exactly one: an explicit user command to distill, promote, or
"整理成規則". If you are reading this file without such a command in the
current conversation, stop — close it and do not act on it.

## Step 1 — cluster

Group entries by category and semantic kinship across BOTH scopes'
`prefer/` stores (a personal and a staged-team entry can share one latent
principle; the promotion target question is settled at final approval).
An entry may join at most one cluster per run.

## Step 2 — induce the principle

For each cluster, derive the smallest single principle that explains:

- every Evidence line of every member entry, AND
- every Except of every member entry — the exceptions must be *predicted*
  by the principle's scope, not tolerated as violations of it.

If no principle explains the Excepts, the cluster is not one principle;
split it or stop. Write the survivor to `<root>/candidates/<slug>.md`:

```markdown
---
candidate: <the rule, stated as it would be enforced>
sources: [<entry-slug>, <entry-slug>]
created: <date>
---

## Scope
<where it applies; enumerated exceptions folded in as scope boundaries>

## Explains
- <entry-slug>: <how its evidence and excepts fit>
```

Distillation deletes nothing. A rejected candidate leaves the store
exactly as it was.

## Step 3 — the five gates

Run in order; the first failure rejects the candidate (record one line of
why at the bottom of the candidate file and stop).

### Gate 1 — support (from usage.log + Evidence)

Aggregate the root's usage.log (under the skill state dir; path in the injected context) per source entry. ALL of:

- user-confirmed Evidence across the cluster ≥ 3 (strong signal:
  corrections and confirmations)
- `applied` events ≥ 10 (relevance: the tendency keeps mattering)
- `overridden` / `applied` ratio < 20% (stability: it is rarely judged
  inapplicable)
- Evidence spans ≥ 3 distinct files and ≥ 2 weeks
- no new Except added to any source entry in the last 14 days (a cluster
  still growing exceptions has unstable boundaries)

`applied` counts are lower bounds (logging is best-effort); undercounting
only defers promotion, which is the safe direction.

### Gate 2 — exception closure

The exception set must be finite, enumerable, and expressible inside the
rule text ("…except in test mock factories"). Any open-ended exception
("視情況", "when it feels noisy") fails the gate — an unenumerable
boundary means the principle is not yet understood.

### Gate 3 — counterexample search (refutation)

Actively search the codebase for existing code that violates the
candidate. Mechanical search (grep/AST) where the rule permits it;
otherwise a sample of ≥ 10 relevant sites. Every violation found must be:

- inside the rule's enumerated scope boundaries, or
- confirmed by the user as known tech debt.

Anything else refutes the candidate. Surviving refutation with real
attempts is what separates a rule from a coincidence of observations.

Gate 3 is also where scope qualifiers are allowed to widen: tendencies
live their whole lives scoped to `observed-in`, and dropping or
broadening a qualifier is precisely the generalization claim this gate
tests. A candidate that survives counterexample search across contexts
its sources never observed has earned the wider scope; one that does not
keeps its qualifier or fails.

### Gate 4 — mechanical-enforceability triage

If the candidate can be expressed as linter/formatter/compiler
configuration (ESLint rule, tsconfig flag, formatter option), the
promotion output IS that configuration — propose the concrete config
change (team scope: as a suggested commit/PR), not prose. After it lands,
delete the source entries: the tool now enforces what the tendency
recorded, and duplicating enforced rules is noise.

Only candidates that cannot be mechanically expressed continue as prose.

### Gate 5 — adversarial debate

Invoke the `multi-debate` skill, `Resolution: judge`, with stances:

- A: promote as stated
- B (mandatory devil's advocate): remain a tendency — argue the legitimate
  situations the rule would wrongly block; this stance's Cost section is
  the true price of promotion
- R (when gate findings suggest it): promote a narrower rule

## Step 4 — final approval

One AskUserQuestion presenting the debate proposals (label = rule text,
description = Argument + Cost) plus `Keep as tendency`. For team scope,
approval means proposing the change to the project (CLAUDE.md section or
lint config) through normal review — the team, not this skill, is the
final authority there.

## Step 5 — after promotion

- Prose rules: append to the agent's own user-level instruction file
  (`~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, whichever the agent reads) or the repo
  CLAUDE.md (team, via the proposed change).
- Delete the promoted source entries and rebuild the index. The rule now
  lives where rules live; the tendency store does not keep tombstones.
- Capture hard-block applies from now on: what CLAUDE.md or tooling states
  is never re-queued.
- **Rule-shadow reclamation** (only where the machine runs a memory
  system): scan its stores for entries semantically equivalent to the
  just-promoted rule — a rule's shadow left in memory keeps getting loaded
  and drifts from the rule over time. List each shadow with its path and
  ask the user before deleting; never reclaim unprompted.

## Log compaction

During any Mode B audit, fold usage.log lines older than 90 days into
per-slug monthly counts in `usage-summary.md` beside it in the skill state
dir, then trim the log. Aggregates in the summary file count toward Gate 1 with the same
weights.

## Demotion

If a promoted rule turns out wrong (the user repudiates it, or it keeps
being overridden), remove it from CLAUDE.md / revert the config, and — if
the underlying lean still exists — recapture it as a fresh tendency
through Mode A. There is no direct rule→tendency edit path; going through
capture keeps Evidence honest.
