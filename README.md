# rather-than

<p align="center">
  <strong>Your coding agent relearns your taste every session.<br />rather-than writes it down — and asks you before it does.</strong>
</p>

<p align="center">
  <a href="https://www.skills.sh/kingdom84521/rather-than"><img src="https://www.skills.sh/b/kingdom84521/rather-than" alt="skills.sh" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/kingdom84521/rather-than?style=flat" alt="License" /></a>
</p>

<p align="center">
  English | <a href="README.zh-TW.md">繁體中文</a>
</p>

```bash
npx plugins add kingdom84521/rather-than
```

## The problem

You have told your agent the same thing four times this month.

Your instruction file — `CLAUDE.md`, `AGENTS.md` — holds the rules you sat down and wrote.
Everything else evaporates when the session ends: the correction you made in passing, the
option you picked when it offered two, the code you quietly rewrote by hand right after it
was generated. The next session starts from zero taste.

The two usual answers each fail in their own way:

- **Memory stores facts.** "The API client lives in `src/api`." That is checkable, and it
  is simply wrong once the file moves. Your taste is not a fact — it is a *choice*: this
  **rather than** that, for a reason, with an exception where the other one wins.
- **Writing it into the instruction file makes it a rule.** Rules do not bend. A rule
  induced from one afternoon's annoyance will fire in the one file where it never belonged,
  and you will be the one deleting it three months later.

So you repeat yourself forever, or you harden every passing remark into law.

## What it does

rather-than sits between the two. It watches ordinary conversation for the moment you
steer — a correction, a demand, a pick between two offers, a complaint in passing — and
writes one line to a journal. Nothing interrupts the task; nothing is announced.

At a natural break point it takes what it collected, throws out the noise, and asks once —
**with receipts**:

> **Prefer `interface` rather than a `type` alias, in exported shapes?**
>
> - `2026-08-04` — you rewrote my `type` alias back to an `interface`, while we were adding the mail-list props.
> - `2026-08-11` — same again, in the compose form's props.
>
> `Personal preference` · `Team convention` · `Defer` · `Never track this`

Answer it and the preference is stored as a **tendency**: injected into every later
session, applied while code is being written, and *mentioned* — never enforced — when the
agent goes the other way.

Nothing reaches the store without that answer. Nothing leaves your machine.

## Why tendencies, not rules

The design constraints that keep this from becoming another linter you switch off:

- **It never blocks and never lectures.** A tendency yields to correctness, to local
  readability, and to its own recorded exceptions. Ask for the opposite and you get the
  opposite, with at most one clause noting the lean.
- **It never writes unconfirmed.** Every pending change is first rendered in plain
  language — what you will see, what you will no longer see, where it applies, and where it
  explicitly does *not* — and waits for your approval.
- **It claims no more than it saw.** Evidence gathered in exported signatures yields a
  preference about exported signatures, never a bare universal. Generalizing beyond that is
  promotion's job, not a tendency's.
- **Exceptions are first-class.** An entry is narrowed with an `Except` or deleted
  outright. There is no tombstone state, and no entry quietly outliving its reason.
- **Becoming a real rule is a separate, gated, command-only step.** Only on your explicit
  command will it try to distill a cluster of tendencies into one principle, and only a
  candidate that survives five gates — support, exception closure, counterexample search,
  mechanical-enforceability triage, adversarial debate — reaches you for approval. What
  clears them becomes a lint rule or a line in your instruction file; the source entries
  are deleted.

## How it differs from the memory plugins

One test tells you which kind of tool you actually want:

> Can the thing you want remembered be phrased as **X rather than Y**, where **Y is not
> wrong** — merely not what you chose?

If Y really is wrong — `rm -rf` pointed at the wrong path, a stray `console.log`, a test
run that never happened — you want a guard, and a guard is a different machine.
[hookify](https://github.com/anthropics/claude-code/tree/main/plugins/hookify) mines the
same signal this does, the things you corrected, and compiles them into regex rules that
block or warn at the tool layer. That is a different problem, and the regex is the tell: no
pattern can express *prefer a named type rather than an inline structural shape, in
exported signatures* — there is no string to match, and both sides are valid code.

If Y is fine, you are choosing between two acceptable options. That is the only thing
rather-than stores.

| | What it carries back | Asks before storing | Exceptions and scope |
|---|---|---|---|
| Session-memory plugins ([claude-mem](https://github.com/thedotmack/claude-mem), [Remember](https://claude.com/plugins/remember), [basic-memory](https://github.com/basicmachines-co/basic-memory)) | what happened, AI-compressed; project facts | no — background hooks | not applicable |
| Built-in auto-memory, `feedback` type | guidance you gave about how to work | no | none |
| `Persona.md` in [remember.md](https://github.com/remember-md/remember) | your code style, AI-maintained | no | none |
| [learning-loop](https://github.com/melodykoh/learning-loop-skill) | corrections, failure modes, judgment shifts | yes, at wrap-up | routes each into a rule or a fact |
| **rather-than** | the choice **and the alternative it beat** | yes — batched, with receipts | `Except` clauses, an `observed-in` scope, and a gated path to becoming a real rule |

Memory answers *what happened* and *what is true*. rather-than answers *what you chose,
instead of what, and where that does not apply*. They stack rather than compete: nothing
here stores project facts, and nothing here replaces a memory plugin's search.

## Install

<details open>
<summary><strong>Claude Code and Codex — one command</strong></summary>

```bash
npx plugins add kingdom84521/rather-than
```

That is the whole install, for every agent the CLI detects. The repo is an
[open-plugin](https://www.npmjs.com/package/plugins) package, so one command brings the
skill and all three hooks, and each agent's own plugin system registers them — no
`settings.json` or `config.toml` editing, nothing to copy.

Preview it first with `npx plugins discover kingdom84521/rather-than`; it should report
`rather-than  1 skill, hooks`. Add `-t claude-code` or `-t codex` to install to one agent
only. Re-run the same command to update.

</details>

<details>
<summary><strong>Skill only — any agent that supports Agent Skills</strong></summary>

The [skills CLI](https://skills.sh) reaches far more agents, but it installs skills and
nothing else — it carries no hook support at all. On that route the hooks are yours to
place, and rather-than does nothing until they are: the hooks are what create the store,
open each session's journal, inject the index every turn, and stop at a break point for
consolidation. The skill on its own is a document nobody opens.

```bash
npx skills add kingdom84521/rather-than -g
git clone https://github.com/kingdom84521/rather-than.git
cp -R rather-than/hooks/rather-than "$HOME/.claude/hooks/"
chmod +x "$HOME/.claude/hooks/rather-than/"*.sh
```

`-g` is not optional: it installs the skill to a user-level skills directory, which is
where the hooks look when no plugin root is set — they try `~/.claude/skills`,
`~/.agents/skills` and `~/.codex/skills` in turn. The default project scope
(`./.claude/skills/`) puts it where they do not look.

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

The shell form is deliberate: the exec form (`args`) skips the shell, so `$HOME` would not
expand.

</details>

<details>
<summary><strong>Verify the install</strong></summary>

Requirements: `bash`, and `jq` (recommended — with it the hooks inject context silently;
without it they fall back to plain stdout, which works but shows up in the transcript).
Bootstrapping from history additionally needs `glab` or `gh`.

Start a new session and check `/hooks` — all three should appear under their events,
attributed to the plugin on the plugin route and to `User` on the manual one. Nothing else
needs creating; the store and its state directories appear on first run.

To exercise the behavior end to end, state a style demand with no technical reason
("always use `for…of` here instead of `forEach`"). Nothing should happen visibly — it is
recorded silently, and the question arrives batched at the next break point.

</details>

## Supported agents

| Agent | Skill | Automatic capture and injection |
|---|---|---|
| Claude Code | yes | yes — `SessionStart`, `UserPromptSubmit`, `Stop` |
| Codex | yes | yes — the same three events, the same `hookSpecificOutput.additionalContext` and `decision: block` contract |
| Cursor | yes | partial, no adapter shipped — `sessionStart` accepts `additional_context`, but `beforeSubmitPrompt` returns only `continue`/`user_message`, so the per-turn reminder has nowhere to go |
| Any other skills-compatible agent | yes | no — it can read and apply the store, but nothing captures or refreshes on its own |

Claude Code and Codex run from the same hook scripts because those two agents share a hook
contract, not because the packaging format makes hooks portable: open-plugin standardizes
where `hooks/hooks.json` lives and rewrites the plugin-root variable per vendor, and passes
everything else through untouched. The store and the judgment are agent-independent; only
the automation needs hooks, and hooks are what most agents still lack.

## How it works

Three parts.

**Hooks** — pure file IO, no LLM calls:

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
<store>/
├── prefer/<slug>.md      # one preference per file — source of truth
├── index.md              # generated topic list, injected every turn
├── journal/<sid>.md      # per-session raw event log
├── deferred/<slug>.md    # candidates you postponed, with receipts kept
├── ignore.md             # topics you opted out of
├── REVIEW.md             # the one pending change awaiting your approval
└── team/<repo-key>/      # team-scope staging, per repository
```

The store root is resolved, not hardcoded: `$RATHER_THAN_HOME` when you set it, else an
existing `~/.claude/rather-than` (so nothing has to move), else
`${XDG_DATA_HOME:-~/.local/share}/rather-than`. It sits outside any single agent's config
directory, and outside the directories a plugin or CLI update manages — which is also why
execution state (locks, usage counts, per-session bookkeeping) lives in `<store>/.state/`
rather than inside the installed plugin, whose path is pinned to a commit and replaced on
every update. Team staging keys off the repo, so the same store follows you across agents
in the same checkout.

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
   anything a linter or formatter already enforces, anything your instruction file already
   states, passive acceptance of something the model proposed. Survivors are written back
   into the journal as candidate blocks, so analysis is never held only in the model's head.

3. **Ask — always with receipts** — one batched question, at most four candidates, each
   carrying its date, what you said, what it was instead of, and what was being worked on.
   A question that cannot show receipts is a question that is not ready to be asked.

4. **Consolidate** — confirmed blocks are merged into `prefer/`, one at a time, behind the
   review gate. Conflicting entries go to an adversarial debate rather than being silently
   overwritten.

Applying a confirmed preference to the code at hand happens immediately, without waiting
for any of the bookkeeping above.

## Scope

| Scope | Root | In git |
|---|---|---|
| personal | `<store>/` | no |
| team (staging) | `<store>/team/<repo-key>/` | no |
| project (published) | `<repo>/.rather-than/` (legacy `<repo>/.claude/rather-than/` still honored) | yes |

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

## Modes

| Mode | Trigger | What it does |
|---|---|---|
| A — capture | automatic | Record, analyze, ask, apply |
| B — consolidate | pending entries, or on request | Merge into `prefer/` behind the review gate |
| C — view & maintain | on request | List, read, edit, delete, publish/unpublish, or score the store for stale and low-quality entries |
| D — promote | explicit command only | Distill a cluster of tendencies into one principle and run it through the five gates; what clears them becomes a lint or tsconfig change where mechanically expressible, otherwise a rule in your instruction file, and the source entries are deleted |
| E — bootstrap | explicit command only | Seed an empty store from history: merge-request review discussions (`glab` / `gh`) and your own correction-shaped commits, queued as ordinary candidates that still need confirming |

Modes D and E never fire on the model's own judgment, and their reference files are not
read into context until you give the command.

## Known limitations

Observed while running this on real work. The first three share one root: the store is
Markdown read at a model's discretion, and nothing enforces how it gets read.

- **Analysis misreads what you meant.** The analysis pass turns raw journal lines into
  candidates, and it takes the wrong end of the stick often enough to matter — the
  instead-of side swapped, a remark scoped to one file generalized into a class of targets,
  a reason inferred that you would never have given. The receipts on the question and the
  review gate are the only correction points, which leaves the whole burden of catching a
  misreading on you.
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
- **The Codex half is verified against the contract, not against a live Codex.** Its
  documented hook events, stdin fields and output schema match Claude Code's, and the hooks
  were exercised end to end against that contract — but on a machine with the Codex CLI
  installed, run `npx plugins discover` and one real session before trusting it.

## Notes

- Concurrent sessions are safe: every capture goes to a per-session journal, and
  consolidation takes an atomic `mkdir` lock that goes stale after 10 minutes. Two sessions
  touching the same preference produce two visible deltas rather than one silent overwrite.
- The hooks are a few `find` probes and one hash per turn — well inside the 30-second
  `UserPromptSubmit` timeout.
- Injected text is phrased as factual statements rather than imperative system commands,
  per the hooks reference guidance on prompt-injection defense.
- `index.md` is derived. Rebuild it with `skills/rather-than/scripts/rebuild-index.sh <root>`;
  never hand-edit it.
- The plugin is authored in the vendor-neutral open-plugin format: `.plugin/plugin.json`
  declares `hooks/hooks.json`, whose commands use `${PLUGIN_ROOT}` — the plugin CLI rewrites
  that to each agent's own variable (`CLAUDE_PLUGIN_ROOT` and friends) as it installs, and
  it rewrites config files only, never scripts. The hook scripts therefore read either
  variable themselves and fall back to a user-level skills directory when neither is set,
  which is what keeps the skills-CLI route working.
- Contested conflicts and promotion's final gate hand off to a separate `multi-debate`
  skill. It is not bundled here; without it those two paths need the debate run by hand.
- `skills/rather-than/evals/scenarios.md` holds the behavior test cases the design is
  checked against — capture positives, filters that must stay silent, batch discipline.
  Real-world failures belong in that file; they outrank synthetic cases.

This repository contains the mechanism only. Preferences, journals, and execution state
live on your own machine and never enter it.
