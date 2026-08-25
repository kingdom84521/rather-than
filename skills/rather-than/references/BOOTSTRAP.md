# Bootstrap from history (Mode E)

Command-only, like Mode D. If you are reading this without an explicit
user command in the current conversation, stop.

Purpose: the preference store starts empty, but evidence already exists —
the team's code-quality culture is sedimented in code review discussions,
and the user's own corrective commits are the historical form of S2
signals. Bootstrap mines both into ordinary `pending` entries; the normal
batch elicitation (A4) remains the only gate into `prefer/`.

## Source 1 — code review discussions (team-convention ore)

Detect the forge CLI: `glab` (GitLab) or `gh` (GitHub), whichever
authenticates in this repo (`glab auth status` / `gh auth status`). If
neither does, report it and continue with Source 2 only.

1. List recently merged reviews:
   GitLab: `glab mr list --merged --per-page 30`
   GitHub: `gh pr list --state merged --limit 30`
2. Fetch the review discussions:
   GitLab: `glab api "projects/:id/merge_requests/<iid>/discussions" --paginate`
   GitHub: `gh api "repos/{owner}/{repo}/pulls/<n>/comments" --paginate`
3. Keep human review notes (exclude system/bot authors).
   A note is a candidate when it asks for a change that is not a bug fix
   — style, naming, structure, "we usually…", "請改成…". Resolved
   discussions where the author complied are the strongest form: a
   correction that was accepted.
4. Cluster semantically identical asks across MRs before queueing — ten
   notes about the same naming habit are ONE candidate with ten Evidence
   lines (MR URLs). Note the reviewer's stated reason as Inferred-Reason.

Queue with `Origin: code-review`. These lean team-scope, but the user still
classifies — a reviewer's personal taste is not automatically a team
convention.

## Source 2 — the user's corrective commits (personal-preference ore)

1. `git log --author=<user> --since='6 months ago' --diff-filter=M
   --pretty=%H -- '*.ts' '*.html' '*.scss'` (adjust patterns to the repo)
2. For commits whose message signals shape-not-behavior change (reword,
   rename, style, cleanup, refactor without issue ref), inspect the diff.
   A recurring transformation pattern — the same kind of before→after
   across commits — is a candidate.
3. Also check commits that closely follow AI-assisted or other-author
   commits touching the same lines: those diffs are literal S2
   corrections.

Queue with `Origin: git-history`. Two occurrences minimum — a single
historical edit is noise.

## Volume discipline

- Cap a bootstrap run at 15 queued candidates, ordered by recurrence
  count. History is large; the point is seeding, not exhaustively mining.
  Re-run later for more.
- Elicitation proceeds in normal A4 waves (four per question set). Spread
  waves across natural break points, not back-to-back.
- Every queued entry carries dated Evidence pointing at MRs/commits, so
  the batch question can show receipts.
- Log outcomes to elicitation.log with their origins (`code-review`,
  `git-history`) like any other source — bootstrap precision is measured
  the same way.

## What not to mine

- Bug fixes, behavior changes, revert commits
- Anything a linter/formatter config already enforced at the time
- Reviewer notes the author pushed back on and did not implement
  (contested, not convention — unless the user says otherwise)
- Other people's preferences: Source 2 mines only the user's own commits
