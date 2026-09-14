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

Your instruction file — `CLAUDE.md`, `AGENTS.md` — only holds the rules you sat down and
wrote. Everything else is gone when the session ends: the correction you made in passing,
the option you picked when the agent offered two, the code you rewrote by hand right after
the agent generated it. The next session starts from zero.

The two usual fixes both fall short:

- **Memory plugins store facts.** "The API client lives in `src/api`" is a fact: you can
  check it, and it becomes wrong the moment the file moves. A preference is not a fact.
  It is a choice — this **rather than** that, for a reason, with exceptions where the
  other side wins.
- **Instruction files store rules.** Rules do not bend. Turn one afternoon's annoyance
  into a rule, and it will fire in the one file where it never belonged. Three months
  later, you are the one deleting it.

So today you either repeat yourself forever, or turn every passing remark into law.

## What it does

rather-than sits between those two. It watches the conversation for the moments you steer
the agent — a correction, a demand, a pick between two options, a passing complaint — and
writes one line to a journal. It never interrupts your task and never announces itself.

At a natural break point, it filters out the noise and asks you once, with the evidence
attached:

> **Prefer `interface` rather than a `type` alias, in exported shapes?**
>
> - `2026-08-04` — you rewrote my `type` alias back to an `interface`, while we were adding the mail-list props.
> - `2026-08-11` — same again, in the compose form's props.
>
> `Personal preference` · `Team convention` · `Defer` · `Never track this`

Answer the question, and the preference is saved as a **tendency**. Every later session
loads it, applies it while writing code, and — when the agent goes the other way —
mentions it in one sentence instead of enforcing it.

Nothing is saved without your answer. Nothing leaves your machine.

## Why tendencies, not rules

Five design rules keep this from becoming another linter you turn off:

- **It never blocks and never lectures.** A tendency gives way to correctness, to local
  readability, and to its own recorded exceptions. Ask for the opposite and you get the
  opposite, plus at most one sentence noting the tendency exists.
- **It never saves anything unconfirmed.** Before a change is written, you see it in plain
  words — what you will see, what you will stop seeing, where it applies, and where it
  does not — and it waits for your approval.
- **It claims no more than it saw.** Evidence from exported signatures produces a
  preference about exported signatures — never a universal rule. Widening the claim is a
  separate step (promotion), and only you can start it.
- **Exceptions are first-class.** An entry is either narrowed with an `Except` clause or
  deleted. There is no archived state, and no entry quietly outlives its reason.
- **Becoming a real rule takes an explicit command.** Only when you say so does it try to
  distill related tendencies into one principle. The candidate must pass five gates —
  support, exception closure, counterexample search, a check whether a linter could
  enforce it instead, and an adversarial debate — before it reaches you for approval.
  What passes becomes a lint rule or a line in your instruction file, and the source
  entries are deleted.

## How it differs from memory plugins

One question tells you which tool you need:

> Can you phrase the thing you want remembered as **X rather than Y**, where **Y is not
> wrong** — just not what you chose?

If Y is actually wrong — `rm -rf` on the wrong path, a leftover `console.log`, a test that
never ran — you need a guard, and a guard is a different tool.
[hookify](https://github.com/anthropics/claude-code/tree/main/plugins/hookify) mines the
same signal this does (the things you corrected), but compiles it into regex rules that
block or warn at the tool layer. The regex shows the difference: no pattern can express
*prefer a named type rather than an inline structural shape, in exported signatures*.
There is no string to match, and both sides are valid code.

If Y is fine, you are choosing between two acceptable options. That choice is the only
thing rather-than stores.

| | What it carries back | Asks before storing | Exceptions and scope |
|---|---|---|---|
| Session-memory plugins ([claude-mem](https://github.com/thedotmack/claude-mem), [Remember](https://claude.com/plugins/remember), [basic-memory](https://github.com/basicmachines-co/basic-memory)) | what happened, AI-compressed; project facts | no — background hooks | not applicable |
| Built-in auto-memory, `feedback` type | guidance you gave about how to work | no | none |
| `Persona.md` in [remember.md](https://github.com/remember-md/remember) | your code style, AI-maintained | no | none |
| [learning-loop](https://github.com/melodykoh/learning-loop-skill) | corrections, failure modes, judgment shifts | yes, at wrap-up | routes each into a rule or a fact |
| **rather-than** | the choice **and the alternative it beat** | yes — batched, with receipts | `Except` clauses, an `observed-in` scope, and a gated path to becoming a real rule |

Memory plugins answer *what happened* and *what is true*. rather-than answers *what you
chose, instead of what, and where that does not apply*. They work together: rather-than
stores no project facts and does not replace a memory plugin's search.

## Install

<details open>
<summary><strong>Claude Code and Codex — one command</strong></summary>

```bash
npx plugins add kingdom84521/rather-than
```

This is the whole install, and it covers every agent the CLI detects. The repo is an
[open-plugin](https://www.npmjs.com/package/plugins) package: one command brings the skill
and all three hooks, and each agent's own plugin system registers them. You edit no
`settings.json` or `config.toml`, and you copy nothing.

To preview first, run `npx plugins discover kingdom84521/rather-than`. It should report
`rather-than  1 skill, hooks`. To install to one agent only, add `-t claude-code` or
`-t codex`. To update, run the same install command again — and see "Updating" below.

</details>

<details>
<summary><strong>Updating — and migrating the store</strong></summary>

Run the install command again, then start a session. If your store's layout is older
than the new version expects, the session context says so in one line and names the
command to run:

```bash
bash <plugin>/skills/rather-than/scripts/init.sh        # plan: what would change; nothing is written
bash <plugin>/skills/rather-than/scripts/init.sh --yes  # apply, after a backup under <store>/.state/backups/
```

You can run it yourself or ask the agent to. Each change to the store's layout ships as
a numbered file under `skills/rather-than/migrations/`, written in the commit that made
the change. `init` only works out which of them your store still needs — from the marker
at `<store>/.state/schema` — and runs them in order. Running it twice is safe: the second
run finds nothing to do. It also reports leftovers from an older install route (a skill
copy under `~/.claude/skills/` while the plugin route is active, hand-registered hooks
that would fire twice) and removes the safe ones with `--prune`. It never edits
`settings.json`.

</details>

<details>
<summary><strong>Skill only — any agent that supports Agent Skills</strong></summary>

The [skills CLI](https://skills.sh) reaches far more agents, but it installs only the
skill — it cannot install hooks. Without the hooks, rather-than does nothing: the hooks
create the store, open each session's journal, inject the index every turn, and pause at
break points for consolidation. So on this route, you place the hooks yourself:

```bash
npx skills add kingdom84521/rather-than -g
git clone https://github.com/kingdom84521/rather-than.git
cp -R rather-than/hooks/rather-than "$HOME/.claude/hooks/"
chmod +x "$HOME/.claude/hooks/rather-than/"*.sh
```

`-g` is required. It installs the skill to a user-level skills directory — where the hooks
look when no plugin root is set. They try `~/.claude/skills`, `~/.agents/skills`, then
`~/.codex/skills`. The default project scope (`./.claude/skills/`) is a place the hooks
never look.

Then register the three hooks in `~/.claude/settings.json`. Add the `hooks` key if it is
missing, and keep any entries you already have:

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

Use this shell form. The exec form (`args`) skips the shell, so `$HOME` would not expand.

</details>

<details>
<summary><strong>Verify the install</strong></summary>

You need `bash`, and ideally `jq`. With `jq`, the hooks inject context silently; without
it, they print to stdout instead — everything still works, but the text shows up in the
transcript. Bootstrapping from history (Mode E) also needs `glab` or `gh`.

Start a new session and run `/hooks`. All three hooks should appear under their events —
attributed to the plugin on the plugin route, or to `User` if you registered them by hand.
You create nothing else: the store and its state directories appear on first run.

To test the whole loop, state a style demand with no technical reason ("always use
`for…of` here instead of `forEach`"). Nothing visible should happen. The demand is
recorded silently, and the question arrives at the next break point.

</details>

## Supported agents

| Agent | Skill | Automatic capture and injection |
|---|---|---|
| Claude Code | yes | yes — `SessionStart`, `UserPromptSubmit`, `Stop` |
| Codex | yes | yes — the same three events, the same `hookSpecificOutput.additionalContext` and `decision: block` contract |
| Cursor | yes | partial, no adapter shipped — `sessionStart` accepts `additional_context`, but `beforeSubmitPrompt` returns only `continue`/`user_message`, so the per-turn reminder has nowhere to go |
| Any other skills-compatible agent | yes | no — it can read and apply the store, but nothing captures or refreshes on its own |

Claude Code and Codex run the same hook scripts because they share the same hook
contract — not because the packaging makes hooks portable. open-plugin only standardizes
where `hooks/hooks.json` lives and rewrites the plugin-root variable per vendor; it passes
everything else through untouched. The store and the judgment work on any agent. Only the
automation needs hooks, and most agents do not have hooks yet.

## How it works

Three parts.

**Hooks** — file operations only, no LLM calls:

| Hook | Event | What it does |
|---|---|---|
| `session-start.sh` | SessionStart | Creates the store if missing (stamped with the current schema), opens this session's journal with a provenance header, rebuilds the index if stale, marks today as an active day, records the usage baseline, says so when the store's layout is behind the plugin, and injects the index plus every path the session needs |
| `prompt.sh` | UserPromptSubmit | Repeats the one-sentence journal duty, refreshes the session's liveness marker and today's activity marker, and injects index changes — only when another session changed the store since this one last read it |
| `stop.sh` | Stop | Blocks the stop once (at most once per 30 minutes per session) when confirmed entries are waiting, so consolidation happens at a break point instead of never. Also blocks once when the response edited files but logged no usage events, so the usage ledger gets reconciled at the break point too |

**The skill** — `SKILL.md` and `references/` hold the judgment: what counts as a
preference signal, what gets filtered out, how a question must be asked, and how two
entries merge.

**The store** — created automatically, one Markdown file per preference:

```
<store>/
├── prefer/<slug>.md      # one preference per file — source of truth
├── index.md              # generated, activation-tiered topic list, injected every turn
├── journal/<sid>.md      # per-session raw event log
├── deferred/<slug>.md    # candidates you postponed, with receipts kept
├── ignore.md             # topics you opted out of
├── REVIEW.md             # the one pending change awaiting your approval
├── team/<repo-key>/      # team-scope staging, per repository
└── .state/               # locks, usage logs, active-day markers, schema marker
```

The store location is resolved at runtime, in this order: `$RATHER_THAN_HOME` if you set
it; an existing `~/.claude/rather-than` (so nothing has to move); otherwise
`${XDG_DATA_HOME:-~/.local/share}/rather-than`. The store sits outside every agent's
config directory, and outside anything a plugin or CLI update replaces. For the same
reason, execution state (locks, usage counts, per-session bookkeeping) lives in
`<store>/.state/`, not inside the installed plugin — the plugin's path is pinned to a
commit and replaced on every update. Team staging is keyed by repository, so the same
store follows you across agents in the same checkout.

## The pipeline

Capture happens in two layers on purpose. Under task pressure, remembering to write one
sentence is far more reliable than running a full classification. And a missed recording
is lost forever, while a wrong analysis can be redone.

1. **Record** (every turn, no judgment). One English sentence per steering event goes into
   the session journal: directives, corrections of the model's output, evaluative remarks
   in passing, picks among offered options, process steering, and codebase patterns the
   model noticed on its own. Each line names what you were working on, and captures the
   rejected side while it still exists — the overwritten draft, the unpicked option, and
   the old behavior all disappear after the turn.

2. **Analyze** (in batches, never mid-task). At a break point, or once enough raw lines
   pile up, the lines pass through a signal taxonomy and a set of hard filters. Filtered
   out: instructions scoped to right now, tasks that name one target instead of a class,
   anything a linter or formatter already enforces, anything your instruction file already
   states, and passive acceptance of the model's own proposal. Survivors are written back
   into the journal as candidate blocks, so the analysis never lives only in the model's
   head.

3. **Ask — always with receipts.** One batched question, at most four candidates. Each
   carries its date, what you said, what the alternative was, and what you were working
   on. A question without receipts is not ready to be asked.

4. **Consolidate.** Confirmed blocks merge into `prefer/` one at a time, behind the review
   gate. Conflicting entries go to an adversarial debate instead of being silently
   overwritten.

Applying a confirmed preference to the code at hand happens immediately. It never waits
for this bookkeeping.

## Scope

| Scope | Root | In git |
|---|---|---|
| personal | `<store>/` | no |
| team (staging) | `<store>/team/<repo-key>/` | no |
| project (published) | `<repo>/.rather-than/` (legacy `<repo>/.claude/rather-than/` still honored) | yes |

Team-classified entries land in local staging first. They reach the repository only when
you publish them, so experimental conventions stay out of your teammates' context. A
published entry is read and applied like any other; new team captures still go to staging.

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
| D — promote | explicit command only | Distill a cluster of tendencies into one principle and run it through the five gates. What passes becomes a lint or tsconfig change where a machine can enforce it, otherwise a rule in your instruction file — and the source entries are deleted |
| E — bootstrap | explicit command only | Seed an empty store from history: merge-request review discussions (`glab` / `gh`) and your own correction-shaped commits, queued as ordinary candidates that still need your confirmation |

Modes D and E never start on the model's own judgment. Their reference files are not even
read into context until you give the command.

## Known limitations

All of these were observed in real work. The first three share one root cause: the store
is Markdown that the model reads at its own discretion, and nothing enforces how. The next
two share another: capture is an instruction the model obeys, with no mechanism behind it
that knows who was speaking or how much was already written.

- **Analysis misreads what you meant.** The analysis step turns raw journal lines into
  candidates, and it gets them wrong often enough to matter: it swaps which side you
  chose, widens a remark about one file into a whole class of targets, or invents a
  reason you never gave. Your only correction points are the receipts on the question and
  the review gate — so catching a misreading is entirely on you. *Should be fixed at
  `e3d3ec2` (span discipline), but not verified yet.*
- **The full entry should be read before writing code — in practice it is not.**
  `SKILL.md` says to open `prefer/<slug>.md` first, and that entries flagged `[N except]`
  *must* be read before use. Nothing enforces that. In practice the model works from the
  injected one-line index and skips the file, so the `Except` clauses — the part that
  keeps a tendency from firing in the wrong place — are the least-read part of the store.
  The usage log cannot measure this either: it records applied / excepted / overridden,
  not whether a file was opened. *Should be fixed at `21e2afc` (Excepts ride in the index
  line; `query.sh` makes the correct read the cheap one), but not verified yet.*
- **Reading the store has no tooling and costs a lot of context.** There is no query: no
  "give me this category's entries", no way to read only some fields. Reading one entry
  means printing the whole file, so consulting a few entries burns context on frontmatter
  and prose the task does not need. That cost feeds the previous item: the cheap path (the
  index, already in context) is always there, and the correct path (the file) is the
  expensive one. *Should be fixed at `21e2afc` (`scripts/query.sh`), but not verified
  yet.*
- **Nothing tells your steering apart from another agent's.** The whole premise is that a
  human steered — journal lines even start with "User…". But a subagent's prompt comes
  from its parent agent, a message between sessions comes from another model, and the hook
  input carries no author identity. So agent-to-agent traffic — parent to child, child to
  parent, sibling to sibling — lands in the journal as if you had said it, and can reach a
  batch question whose receipts quote an AI instead of you. Until the store records who
  was speaking, treat receipts from a session you did not drive yourself as suspect.
  *Should be fixed at `d05757b` (author discipline plus a zeroth analysis gate — though it
  is discipline, not mechanism), but not verified yet.*
- **How much gets recorded depends on the client, not on how much you steered.** The duty
  is one line of injected text that the model obeys. There is no counter, no rate limit,
  and no deduplication at write time, so eagerness varies by where it runs — the VS Code
  extension appears to journal more than the terminal CLI for the same work. The store
  cannot measure this either: the provenance header records session, repo, staging root
  and start time, but no client identity. So this stays an impression, not a number.
  *Partially fixed at `d05757b` (client identity in the provenance header makes it
  measurable; one-event-one-line dedup), but not verified yet — and there is still no
  counter or rate limit.*
- **The Codex side is verified against the documented contract, not against a live
  Codex.** Its documented hook events, stdin fields and output schema match Claude Code's,
  and the hooks were tested end to end against that contract. Before trusting it, run
  `npx plugins discover` and one real session on a machine with the Codex CLI installed.

## Notes

- Concurrent sessions are safe. Every capture goes to its own session's journal, and
  consolidation takes an atomic `mkdir` lock that expires after 10 minutes. If two
  sessions touch the same preference, you get two visible changes, not one silent
  overwrite.
- The hooks cost a few `find` probes and one hash per turn — far below the 30-second
  `UserPromptSubmit` timeout.
- Injected text is written as factual statements, not imperative system commands,
  following the hooks reference guidance on prompt-injection defense.
- `index.md` is generated. Rebuild it with
  `skills/rather-than/scripts/rebuild-index.sh <root> [<state-dir>]`. Never edit it by
  hand.
- The index is tiered the way habits are. An entry earns always-on (`habitual`) status
  through use: its activation is scored ACT-R-style from usage.log events, Evidence dates
  and `created` — frequent and recent use raises the score, which decays by a power law.
  Unused entries sink back to `cold`, and repeated overrides force an entry cold. Cold
  entries inject as `category: count (slugs)` only and are consulted through `query.sh`
  when the work touches them. The habitual tier holds at most `RATHER_THAN_HABIT_MAX`
  entries (default 15). The hooks refresh the index daily, so decay follows time, not
  only writes.
- The usage ledger does not rely on the model remembering to write it. `query.sh` itself
  logs every entry it prints as a `consulted` event (pass `-n` for maintenance reads that
  should not count as use), and the Stop hook forces a reconciliation moment when a
  response edited files but logged nothing. Decay counts *active days* — days the hooks
  saw the store in use — so three weeks away cools nothing. Habits fade from missed
  practice, not from the calendar.
- `skills/rather-than/scripts/query.sh <root>` is the cheap way to read entries: `-c`
  filters by category, `-s` picks slugs, `-m` matches text, `-f` picks fields. The
  default output (topic, `observed-in`, Except) is what applying a tendency needs.
- The store has a schema. `<store>/.state/schema` holds the id of the last layout
  migration applied; `skills/rather-than/migrations/` holds every migration — one file per
  layout change, written in the commit that made it — plus the ledger that maps them to
  commits. `scripts/init.sh` plans and applies the ones a store still needs. What file
  work cannot do (re-reading journals written before the author rule, restoring spans a
  candidate never recorded) is written down as a rule instead — DETECTION.md's
  legacy-journal rule, `inferred` spans confirmed by the question — never guessed by a
  script.
- The plugin uses the vendor-neutral open-plugin format. `.plugin/plugin.json` declares
  `hooks/hooks.json`, whose commands use `${PLUGIN_ROOT}`. At install time, the plugin CLI
  rewrites that variable to each agent's own name (`CLAUDE_PLUGIN_ROOT` and friends) — and
  it rewrites config files only, never scripts. The hook scripts therefore read either
  variable themselves, and fall back to a user-level skills directory when neither is set.
  That fallback is what keeps the skills-CLI route working.
- Contested conflicts and promotion's final gate hand off to a separate `multi-debate`
  skill. It is not bundled here; without it, you run those two debates by hand.
- `skills/rather-than/evals/scenarios.md` holds the behavior test cases the design is
  checked against: capture positives, filters that must stay silent, batch discipline.
  Real-world failures belong in that file, and they outrank synthetic cases.

This repository contains only the mechanism. Your preferences, journals, and execution
state stay on your machine and never enter this repo.
