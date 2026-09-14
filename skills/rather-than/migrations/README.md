# Store migrations

The store's layout has changed several times since the first commit. Each
change is recorded here as a numbered migration, **written in the same commit
as the change** — never derived at run time. `scripts/init.sh` decides only
two things when it runs: *which* of these files still apply to the store in
front of it (its schema marker against the highest id shipped here), and
*how* they run (plan only, or apply after a backup, optionally stopping at a
given id). It never works out how to migrate.

## Schema ledger

The schema id is the id of the last migration applied. It lives at
`<store>/.state/schema`; `<store>/.state/migrations.log` records every run.
A store with no marker is schema 0 — every migration is asked, and each one
finds nothing to do when its shape is already present, so running the whole
ladder on a store of unknown age is safe.

| Schema | Since | Date | What changed in the store | Migration |
|---|---|---|---|---|
| 0 | `9091f88` | 2026-08-25 | Baseline. Store at `~/.claude/rather-than/`; project root at `<repo>/.claude/rather-than/`; execution state (usage logs, session markers, locks, `elicitation.log`) **inside the installed skill** at `~/.claude/skills/rather-than/.state/`; flat `index.md`; journal header `session \| repo \| team-staging-root \| started`; candidate blocks without `Spans`. | — |
| 1 | `7b59ed7` | 2026-08-25 | Execution state moved to `<store>/.state/`, where a skill or plugin update cannot take it. Store root became `$RATHER_THAN_HOME` → existing `~/.claude/rather-than` → `${XDG_DATA_HOME:-~/.local/share}/rather-than`; project root became `<repo>/.rather-than/` for new repos. Both old locations stay honored, so only the state needs moving. | `001-state-into-store.sh` |
| 2 | `e3d3ec2` | 2026-09-09 | `## candidate /` journal blocks gained a `- Spans:` line (the faithfulness gate: each load-bearing part of a topic points at a verbatim receipt, or is `inferred`). | `002-candidate-spans.sh` marks all three parts `inferred`. Semantic remainder: the real spans are restored by the A3 question, which confirms `inferred` parts instead of asserting them — no separate step. |
| 3 | `d05757b` | 2026-09-09 | Journal provenance header gained a `client` field between `team-staging-root` and `started`; the same commit made "User" mean the human and one event take one line. | `003-journal-client-field.sh` writes `client unrecorded`. Semantic remainder: those journals' raw lines were written under the old rules — DETECTION.md's legacy-journal rule, keyed on `client unrecorded`, says how analysis reads them. |
| 4 | `e4e29d1` (line format also at `21e2afc`) | 2026-09-10 | `index.md` became activation-tiered (`## habitual` / `## cold`); `rebuild-index.sh` takes the root's state dir. The index is derived, so the migration is a rebuild. | `004-tiered-index.sh` |
| 5 | `e6953c6` | 2026-09-10 | Activation ages in **active days**: `.state/activity/<YYYY-MM-DD>` markers, touched by the hooks. Also `.state/sessions/<sid>.usize` and the `consulted` usage verb (both additive, nothing to migrate). Without markers for the days before the upgrade, every old event looks one day old and the tiers come out wrong. | `005-activity-backfill.sh` |
| 5 | the `init` commit | 2026-09-14 | The schema marker itself, `migrations.log`, and `init.sh`. A fresh store is stamped by the SessionStart hook; an existing store is stamped by `init.sh`. | — |

Commits absent from the table (`724a873` packaging, `a179c72`, `fe9a08e`,
`cc014c1`, `d05757b`'s analysis gate, the README rewrites) changed the
plugin, not the store.

## Migration file contract

`init.sh` sources each `NNN-<slug>.sh` in id order with these in scope:

| Name | Meaning |
|---|---|
| `STORE`, `STATE` | personal store root and its `.state/` dir |
| `ROOTS` | newline-separated list of every root in this run: personal, each `team/<repo-key>/`, and the current repo's project root when it exists |
| `state_for_root <root>` | the state dir that root's `usage.log` lives in |
| `SCRIPTS` | the skill's `scripts/` dir (`rebuild-index.sh` lives there) |
| `say <text>` | one line of plan or progress output |

Each file defines:

| Name | Meaning |
|---|---|
| `MIG_SINCE`, `MIG_DATE`, `MIG_TITLE` | the commit that changed the layout, its date, one line |
| `mig_plan` | prints one `say` line per action it would take; prints nothing when the store already has this shape |
| `mig_apply` | takes those actions |
| `mig_semantic` (optional) | prints the instructions for the part that needs judgment rather than file work; `init.sh` appends them to `<store>/.state/migrations.todo.md` when the migration applied, and the SessionStart hook surfaces that file until the model has worked each section through the normal gates and deleted it |

Rules every migration keeps:

- **Idempotent.** Re-running on a migrated store does nothing. `mig_plan`
  printing nothing is the definition of "nothing to do".
- **Never destroys user data.** Move, append, add, rebuild derived files.
  Anything that would be overwritten is set aside and reported, not deleted.
- **Self-contained.** No network, no LLM, seconds to run, plain `bash` +
  `awk`/`sed`/`find`, the same floor the hooks have.
- **Written with the change.** A commit that alters the store's layout adds
  the next-numbered file and a row above, in the same commit. The hooks and
  `init.sh` discover the highest id from this directory; nothing else is
  bumped.
- **As mechanical as it can be, and no more.** Everything file work can do,
  `mig_apply` does. What it cannot — recovering meaning the old layout never
  recorded — is written down rather than guessed: as a permanent rule in the
  skill when a durable signal identifies the legacy data (003 leaves `client
  unrecorded` in the header; DETECTION.md's legacy-journal rule keys on it),
  or as a `mig_semantic` block when it is one-time work for the model and
  the user.

## Adding one

1. Take the next id: `NNN-<what-it-does>.sh`. Copy the header shape from an
   existing file.
2. Set `MIG_SINCE` to the commit that changes the layout (amend it in after
   committing, or reference the commit whose change the migration serves).
3. Write `mig_plan` first — the plan is the specification. Then `mig_apply`.
4. Test on a fixture store in the old shape, run `init.sh --yes` twice, and
   check the second run is all no-ops.
5. Add the row to the ledger, and a scenario under "Store schema and
   migration" in `evals/scenarios.md` if behaviour changes.
