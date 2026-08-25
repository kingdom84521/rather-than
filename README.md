# rather-than

English | [繁體中文](README.zh-TW.md)

A [Claude Code](https://claude.com/claude-code) skill plus three hooks that record
*why* you write code a particular way, so later sessions do not re-litigate settled
decisions.

`CLAUDE.md` is where rules live. But most of what makes a codebase feel like yours is
softer than a rule — "prefer an explicit generic rather than an inferred one", "prefer a
guard the type system enforces rather than a convention plus a comment". State one of
those in a session and it dies with the session. rather-than captures them from ordinary
conversation, confirms each one with receipts before storing it, and injects the store
back into every turn.

Entries are **tendencies, not rules**: warning-level leanings that never block, never
lecture, and yield to correctness, to local readability, and to their own recorded
exceptions. Turning a tendency into an actually-enforced rule is a separate, gated,
command-only step.

## How it works

Three parts.

**Hooks** — pure file IO, no LLM calls, all under `~/.claude/hooks/rather-than/`:

| Hook | Event | What it does |
|---|---|---|
| `session-start.sh` | SessionStart | Creates the store if absent, opens this session's journal with a provenance header, rebuilds a stale index, and injects the store index plus every path this session needs |
| `prompt.sh` | UserPromptSubmit | Re-states the one-sentence journal duty each turn, keeps the session's liveness marker fresh, and — only when the store changed since this session last read it, typically under a concurrent session — injects the changed index lines rather than the whole index |
| `stop.sh` | Stop | When confirmed entries are waiting, blocks the stop once (rate-limited to once per 30 min per session) so consolidation happens at a natural break point instead of never |

**The skill** — `SKILL.md` and `references/`, holding the judgment: what counts as a
preference signal, what gets filtered out, how a question must be asked, how two entries
merge.

**The store** — created automatically, one Markdown file per preference:

```
~/.claude/rather-than/
├── prefer/<slug>.md      # one preference per file — source of truth
├── index.md              # generated topic list, injected every turn
├── journal/<sid>.md      # per-session raw event log
├── deferred/<slug>.md    # candidates you postponed, with receipts kept
├── ignore.md             # topics you opted out of
├── REVIEW.md             # the one pending change awaiting your approval
└── team/<repo-key>/      # team-scope staging, per repository
```

Execution state — locks, usage counts, per-session bookkeeping — lives under
`~/.claude/skills/rather-than/.state/`, never in the store and never in a repository.

## The pipeline

Capture is split in two layers on purpose: remembering to write one sentence is far more
robust under task pressure than running a classification, and a recording miss is
unrecoverable while an analysis mistake can be retried.

1. **Record** (every turn, no judgment) — one English sentence per steering event into the
   session journal: directives, corrections of the model's output, evaluative remarks in
   passing, picks among offered options, process steering, plus the model's own
   observations of codebase patterns. Each line names what was being worked on, and
   captures *the instead-of side while it still exists* — the overwritten draft, the
   unpicked option, the current behavior all evaporate after the turn.

2. **Analyze** (in batches, never mid-task) — at a break point, or once enough raw lines
   pile up, the lines go through a signal taxonomy and a set of hard filters: an
   instruction scoped to now, a task that names one target rather than a class of targets,
   anything a linter or formatter already enforces, anything `CLAUDE.md` already states,
   passive acceptance of something the model proposed. Survivors are written back into the
   journal as candidate blocks, so analysis is never held only in the model's head.

3. **Ask — always with receipts** — one batched question, at most four candidates, each
   carrying its date, what you said, what it was instead of, and what was being worked on.
   Answers: *personal preference*, *team convention*, *defer* (re-asked when the topic
   next comes up live), or *never track this*. A question that cannot show receipts is a
   question that is not ready to be asked.

4. **Consolidate** — confirmed blocks are merged into `prefer/`, one at a time, behind a
   review gate: each pending change is rendered into `REVIEW.md` in plain language — what
   you will see, what you will no longer see, where it applies, where it explicitly does
   *not* — and nothing is written until you approve that rendering. Conflicting entries go
   to an adversarial debate rather than being silently overwritten.

Applying a confirmed preference to the code at hand happens immediately, without waiting
for any of the bookkeeping above.

## Scope

| Scope | Root | In git |
|---|---|---|
| personal | `~/.claude/rather-than/` | no |
| team (staging) | `~/.claude/rather-than/team/<repo-key>/` | no |
| project (published) | `<repo>/.claude/rather-than/` | yes |

Team-classified entries land in local staging first and reach the repository only when you
explicitly publish them, which keeps experimental conventions out of everyone else's
context. A published entry is read and applied like any other; new team captures still go
to staging.

## What an entry looks like

```markdown
---
topic: Prefer a named type rather than an inline structural shape, in exported signatures
scope: team
confidence: confirmed
category: types & API shape
observed-in: [http client wrappers, store selectors]
created: 2026-07-22
---

## Reason
An inline shape has no name to search for, so the next person changing the contract
cannot find its other end.

## Except
- Single-use local callback parameters
  - Reason: naming a type used once, one line away, costs more than it explains.

## Evidence
- 2026-07-22 src/api/client.ts:41
```

Two properties keep the store honest. A topic claims **no more than `observed-in`
covers** — evidence gathered in exported signatures yields a preference about exported
signatures, never the bare universal. Widening it beyond the contexts it was actually
observed in is generalization, and generalization is promotion's job, not a tendency's.
And there is **no supersede state**: an entry is either narrowed with an `Except` or
deleted outright. Nothing lingers as a tombstone.

## Modes

| Mode | Trigger | What it does |
|---|---|---|
| A — capture | automatic | Record, analyze, ask, apply |
| B — consolidate | pending entries, or on request | Merge into `prefer/` behind the review gate |
| C — view & maintain | on request | List, read, edit, delete, publish/unpublish, or score the store for stale and low-quality entries |
| D — promote | explicit command only | Distill a cluster of tendencies into one principle and run it through five gates — support, exception closure, counterexample search, mechanical-enforceability triage, adversarial debate. What clears them becomes a lint or tsconfig change where mechanically expressible, otherwise a `CLAUDE.md` rule, and the source entries are deleted |
| E — bootstrap | explicit command only | Seed an empty store from history: merge-request review discussions (`glab` / `gh`) and your own correction-shaped commits, queued as ordinary candidates that still need confirming |

Modes D and E never fire on the model's own judgment, and their reference files are not
read into context until you give the command.

## Install

Requirements: Claude Code, `bash`, and `jq` (recommended — with it the hooks inject
context silently; without it they fall back to plain stdout, which works but shows up in
the transcript). Mode E additionally needs `glab` or `gh` to mine review discussions.

### 1. The skill

```bash
npx skills add kingdom84521/rather-than -g
```

`-g` is not optional here. It installs to `~/.claude/skills/rather-than/`, which is the
path the hooks resolve the skill's scripts from; the default project scope
(`./.claude/skills/`) puts them where the hooks do not look. The whole bundle travels —
`references/`, `scripts/`, `evals/` — and the scripts keep their executable bit.

### 2. The hooks

The [skills CLI](https://skills.sh) installs skills, not hooks, so this half is manual —
and rather-than does nothing without it. The hooks are what create the store, open each
session's journal, inject the index every turn, and stop at a break point for
consolidation. The skill on its own is a document nobody opens.

```bash
git clone https://github.com/kingdom84521/rather-than.git
cp -R rather-than/hooks/rather-than "$HOME/.claude/hooks/"
chmod +x "$HOME/.claude/hooks/rather-than/"*.sh
```

Then register the three hooks in `~/.claude/settings.json` — add the `hooks` key if it is
absent, and do not replace entries you already have:

```json
{
  "hooks": {
    "SessionStart": [
      { "hooks": [{ "type": "command", "command": "bash \"$HOME/.claude/hooks/rather-than/session-start.sh\"" }] }
    ],
    "UserPromptSubmit": [
      { "hooks": [{ "type": "command", "command": "bash \"$HOME/.claude/hooks/rather-than/prompt.sh\"" }] }
    ],
    "Stop": [
      { "hooks": [{ "type": "command", "command": "bash \"$HOME/.claude/hooks/rather-than/stop.sh\"" }] }
    ]
  }
}
```

The shell form is deliberate: the exec form (`args`) skips the shell, so `$HOME` would
not expand.

### 3. Verify

Start a new session and check `/hooks` — all three should appear under their events with
source `User`. Nothing else needs creating; the store and its state directories appear on
first run.

To verify the behavior end to end, state a style demand with no technical reason
("always use `for…of` here instead of `forEach`"). Nothing should happen visibly — it is
recorded silently, and the question arrives batched at the next break point.

### Updating

`npx skills update rather-than` refreshes the skill; the hooks need their `cp -R` run
again. Your store is never touched by either — it lives outside both directories.

## Notes

- Concurrent sessions are safe: every capture goes to a per-session journal, and
  consolidation takes an atomic `mkdir` lock that goes stale after 10 minutes. Two
  sessions touching the same preference produce two visible deltas rather than one silent
  overwrite.
- The hooks are a few `find` probes and one hash per turn — well inside the 30-second
  `UserPromptSubmit` timeout.
- Injected text is phrased as factual statements rather than imperative system commands,
  per the hooks reference guidance on prompt-injection defense.
- `index.md` is derived. Rebuild it with `skills/rather-than/scripts/rebuild-index.sh <root>`;
  never hand-edit it.
- Contested conflicts (Mode B) and promotion gate 5 (Mode D) hand off to a separate
  `multi-debate` skill. It is not bundled here; without it those two paths need the debate
  run by hand.
- `skills/rather-than/evals/scenarios.md` holds the behavior test cases the design is
  checked against — capture positives, filters that must stay silent, batch discipline.
  Real-world failures belong in that file; they outrank synthetic cases.

## Known issues

Observed while running this on real work. All three share one root: the store is Markdown
read at a model's discretion, and nothing enforces how it gets read.

- **Analysis misreads what you meant.** The analysis pass turns raw journal lines into
  candidates, and it takes the wrong end of the stick often enough to matter — the
  instead-of side swapped, a remark scoped to one file generalized into a class of targets,
  a reason inferred that you would never have given. The receipts on the question and the
  `REVIEW.md` gate are the only correction points, which leaves the whole burden of
  catching a misreading on you.
- **The full entry is supposed to be read before writing code, and in practice is not.**
  `SKILL.md` says to open `prefer/<slug>.md` first, and that entries flagged `[N except]`
  *must* be read before use. Nothing enforces it, and in practice the model works off the
  injected one-line index and skips the file — so `Except` clauses, the very part that
  keeps a tendency from misfiring, are the least-read part of the store. The usage log
  cannot measure this either: it records applied / excepted / overridden, not whether a
  file was opened.
- **Reading the store has no tooling and costs a lot of context.** There is no query — no
  "give me this category's entries", no field projection. Reading one entry means `cat`ing
  the whole file, so consulting a handful burns a large amount of context on frontmatter
  and prose the task at hand does not need. That cost feeds the previous item: the cheap
  path (the index, already in context) is always there, and the correct path (the file) is
  the expensive one.

This repository contains the mechanism only. Preferences, journals, and execution state
live under your own `~/.claude/` and never enter it.
