# rather-than eval scenarios

Design-derived test cases for the capture/apply behavior. Run manually or
via skill-creator's eval mechanism: present the prompt in a session with
the listed store state, check the expectation. Add real-world failure
cases to this file as they occur — field cases outrank synthetic ones.

Legend: RECORD = one natural-sentence raw line appears in the session
journal this turn, no question asked, no mention to the user. CANDIDATE =
at the next analysis trigger, extraction produces a candidate for the
batch question. FILTERED = recorded as raw, but analysis drops it (no
question ever reaches the user). NOTHING = not even recorded.

## Capture positives

| id | Store state | Prompt / event | Expect |
|---|---|---|---|
| S1-quantifier | empty | "以後 subscribe 一律先 takeUntilDestroyed" | RECORD + CANDIDATE |
| S1-taste-reason | empty | "用 interface 不要 type，我覺得比較乾淨" | RECORD + CANDIDATE, taste as inferred reason |
| S2-revert | empty | user rewrites Claude's correct `type` to `interface`, second time | RECORD both times; CANDIDATE on recurrence, raw line names the overwritten side |
| S3-codebase | empty | while fixing a bug, Claude reads 4 services all hand-rolling Result objects | RECORD (observation) + CANDIDATE, ≥3 witnesses |
| S5-passing | empty | "上次那個專案就是被 barrel file 搞死…anyway 幫我改這個 bug" | RECORD both (complaint + task); complaint → CANDIDATE; bug still fixed this turn |
| S6-pick | Claude offered 2 valid options twice; user picked the explicit variant both times | second pick | RECORD each pick incl. unpicked option; CANDIDATE on second |
| S7-workflow | empty | "commit 拆小一點，一個概念一個 commit" | RECORD + CANDIDATE (process) |
| S8-domain | empty | "時間單位我們要自動進位...16h就要變成2d" | RECORD + CANDIDATE (domain convention; generalization test passes) |
| S8-spec-neg | empty | "這個欄位顯示成 2d" | RECORD; FILTERED (names a target, not a class) |

## Analysis filters (recorded raw, never reach the user)

| id | Prompt / event | Expect |
|---|---|---|
| HF-task | "把 handle 改名成 submitOrder" | RECORD; FILTERED (task names a target) |
| HF-now | "先 hardcode，API 好了再改" | RECORD; FILTERED (scoped to now) |
| HF-lint | demand matches an ESLint rule already in repo config | RECORD; FILTERED |
| HF-accept | Claude proposes one approach, user says "ok" | NOTHING (no steering event) |
| HF-claudemd | demand restates an existing CLAUDE.md rule | RECORD; FILTERED |
| HF-infoq | "這個 API 怎麼用?" | NOTHING (pure information question) |

## Batch discipline

| id | Setup | Expect |
|---|---|---|
| B-trigger8 | 8th unanalyzed raw line lands mid-task | analysis NOT run mid-task; runs at next turn start |
| B-break | 3 raw lines, user says "好 這樣就好" | analysis + question fire (break point) |
| B-marker | analysis ran once already | next analysis reads only lines below the newest marker |
| B-onequestion | analysis yields 5 candidates | one AskUserQuestion call, ≤4 questions, wave for the rest |

## Apply behavior

| id | Store state | Prompt | Expect |
|---|---|---|---|
| AP-follow | entry: explicit-return-type [0 except] | "寫一個 service method" | code follows entry; usage.log gains `applied` |
| AP-except | entry with Except: test factories | "寫這個 mock factory" | Except honored; `excepted` logged; no mention needed |
| AP-override-explicit | entry: no-abbrev-names | "這邊用縮寫 idx 就好" | comply immediately, one-clause mention, nothing recorded (one-off tone) |
| AP-repudiate | entry: one-op-per-line | "以後不要再一個 operator 一行了" | comply this turn + RECORD repudiation; analysis yields DELETE candidate |
| AP-noblock | any entry | user demands violating code, intent unclear | code produced THIS turn (never blocked), queued |

## Receipts and deferral

| id | Setup | Expect |
|---|---|---|
| R-receipts | any batch question | question text quotes date + original words + instead-of + task context; a bare topic line fails |
| R-defer | user picks Defer on a candidate | deferred/<slug>.md created with full analysis + source quotes; nothing re-derived later |
| R-reask | deferred topic exists; new related raw line lands | next batch re-asks it FIRST, with old and new receipts |
| R-defer3 | defer-count reaches 3 | question notes "deferred twice already — Never is fine" |
| R-consolidate | Mode B runs, journals deleted | deferred/ files untouched, quotes intact |

## Root cause and scope

| id | Setup | Expect |
|---|---|---|
| L-ladder | candidate reaches A3 | reason options are consequence-level (survive one "why"); a topic-restating reason never appears |
| L-compete | raw lines support two readings | both hypotheses offered, not just the convenient one |
| L-probe | no reason derivable | question asks the laddering probe ("這在保護什麼?") free-text |
| SC-context | any raw line | contains a working-context clause; context-free lines fail |
| SC-qualified | evidence only from report displays | topic reads "…, in user-facing displays"; bare universal fails |
| SC-extend | entry scoped to displays; current task is API serialization | apply if sensible + RECORD first-extension line; no silent universal treatment |
| SC-widen | user asks to drop a qualifier outside Mode D | declined as promotion-only; offered as Mode D |
| M-scaled | user violates entry with 30 applied + 5 evidence | mention carries receipts; fresh inferred entry violation gets one clause; both comply |

## Backlog integrity and routing

| id | Setup | Expect |
|---|---|---|
| BL-orphan-fresh | session ended (committed) 5 min ago, alive marker stale | its raw lines are adoptable NOW — no 24h wait |
| BL-strong-safe | 6 candidates, one with 4 evidence + absolute quantifier | strong one is in wave 1 regardless of age; overflow candidates persist as journal blocks |
| BL-drain | Mode B finishes; one journal still holds a candidate block | that journal is NOT deleted |
| RT-fact | raw line: "Set has isSubsetOf" | not a candidate (fact) — exits at the routing gate |
| RT-bound | fact+decision bound in one line | split: fact exits, decision continues |
| RT-memhit | candidate matches an unconfirmed memory entry | capture proceeds; memory path counted as extra Evidence; reclamation flagged after confirm |
| UC-scan | entry lacks category (uncategorized section) | still scanned on implicit path; audit backfills category |

## Review gate, elaboration discipline, maintenance commands

| id | Setup | Expect |
|---|---|---|
| RV-perentry | Mode B has 3 pending changes | REVIEW.md holds ONE entry at a time; confirm each before its write; next entry only after |
| RV-gist | any REVIEW.md content | leads with one-sentence bottom line + you'll/won't-see examples; a field dump fails |
| RV-danger | entry has excepts + scope qualifier | both in plain language, marked as danger zones |
| EL-bind | user answers the asked question + adds two new preferences in one reply | answer applied; extras become raw lines/candidates, NOT merged into the entry |
| EL-contradict | user's elaboration contradicts recorded Evidence | tension surfaced in chat; record not silently rewritten |
| MC-review | user: "review my preferences" | numbered category-grouped list in chat first; translation only after a pick; zero writes |
| MC-clean | user: "clean the store" | scorer runs (cached); only ≥30 shown with score + top factors; remedies map to factors; nothing auto-fixed |
| MC-clean-cache | clean run twice, no changes between | second run reuses hygiene.tsv fingerprints |

## Promotion safety

| id | Event | Expect |
|---|---|---|
| P-noauto | audit finds 5 entries in `naming` | one-sentence fact at most; PROMOTE.md NOT read |
| P-cmd | user: "把 naming 那群整理成規則" | PROMOTE.md read, Mode D runs |
| E-noauto | session start, empty store | BOOTSTRAP.md NOT read, no bootstrap suggestion pushed |
