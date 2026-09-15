#!/usr/bin/env bash
# SessionStart hook for rather-than.
# Emits JSON additionalContext (silent injection). Falls back to plain stdout
# if jq is unavailable (plain stdout is also injected for this event, just
# visibly). Factual phrasing only — no imperative system-command framing.
set -uo pipefail

input="$(cat)"

get_field() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$input" | jq -r ".$1 // empty" 2>/dev/null
  else
    printf '%s' "$input" | sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -n1
  fi
}

. "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/paths.sh"
sid="$(get_field session_id)"; [ -n "$sid" ] || sid="unknown-$$"
cwd="$(get_field cwd)"; [ -n "$cwd" ] || cwd="$PWD"

skill_scripts="$(rt_skill_scripts)"
skill_root="${skill_scripts%/scripts}"
# Resolve repo identity: git root if available, else cwd.
repo_root="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$repo_root" ] || repo_root="$cwd"
repo_key="$(basename "$repo_root")-$(printf '%s' "$repo_root" | sha256sum | cut -c1-8)"

personal="$(rt_store_root)"
teamlocal="$personal/team/$repo_key"
project="$(rt_project_root "$repo_root")"
state_base="$personal/.state"
state_personal="$state_base/personal"
state_team="$state_base/team-$repo_key"
state_project="$state_base/project-$repo_key"


# A store is fresh when this run creates it; an existing store keeps its schema.
fresh=0; [ -d "$personal/prefer" ] || fresh=1
mkdir -p "$personal/prefer" "$personal/journal" "$teamlocal/prefer" "$state_base/sessions" "$state_base/activity" "$state_personal" "$state_team"

# Store schema: every change to the store's layout ships as a numbered file
# under the skill's migrations/, and .state/schema records the last one
# applied. A store created here starts at the newest; an older store gets
# one line asking for init. The hook never migrates anything itself.
schema_note=""
schema_latest="$(ls "$skill_root/migrations"/[0-9][0-9][0-9]-*.sh 2>/dev/null | sed 's#.*/\([0-9][0-9][0-9]\)-.*#\1#' | sort -n | tail -n 1)"
if [ -n "$schema_latest" ]; then
  schema_latest=$((10#$schema_latest))
  schema_have="$(cat "$state_base/schema" 2>/dev/null || echo 0)"
  case "$schema_have" in ''|*[!0-9]*) schema_have=0 ;; esac
  if [ "$fresh" = 1 ] && [ ! -f "$state_base/schema" ]; then
    printf '%s' "$schema_latest" > "$state_base/schema" 2>/dev/null || true
  elif [ "$schema_have" -lt "$schema_latest" ]; then
    schema_note="Store schema is $schema_have; this plugin ships $schema_latest. The pending migrations are recorded under $skill_root/migrations/ — plan with bash \"$skill_scripts/init.sh\", apply with --yes (a backup is taken first). Run it before any Mode B or Mode C write; the tiers below may be off until then."
  fi
  if [ -s "$state_base/migrations.todo.md" ]; then
    schema_note="$schema_note${schema_note:+ }Semantic migration steps await in $state_base/migrations.todo.md — work each section through the normal gates at the next Mode B and delete it when done."
  fi
fi

# Cloud sync (opt-in, <store>/cloud.conf): report the last result and any kept
# conflict copies, then refresh in the background — never on the session's
# critical path. Whatever it pulls reaches this session through the index
# change detection on the next prompt.
cloud_note=""
cloud_conf="${RATHER_THAN_CLOUD_CONFIG:-$personal/cloud.conf}"
if [ -f "$cloud_conf" ] && [ ! -f "$state_base/cloud/off" ] && [ "${RATHER_THAN_CLOUD:-}" != off ]; then
  cloud_last="$(cat "$state_base/cloud/last" 2>/dev/null || echo never)"
  cloud_nconf="$(find "$state_base/cloud/conflicts" -type f 2>/dev/null | wc -l | tr -d ' ')"
  cloud_note="Cloud sync is on (adapter $(sed -n 's/^adapter[[:space:]]*=[[:space:]]*//p' "$cloud_conf" | head -n 1)); last run: $cloud_last. A background sync started now — anything it pulls shows up as an index change on the next prompt."
  if [ "${cloud_nconf:-0}" -gt 0 ]; then
    cloud_note="$cloud_note $cloud_nconf conflict copy(ies) wait under $state_base/cloud/conflicts/ — each is the losing side of an edit made on two machines: in Mode C, compare it with the live prefer/<slug>.md, fold in what is missing, delete the copy (bash \"$skill_scripts/cloud.sh\" conflicts lists them)."
  fi
  if command -v setsid >/dev/null 2>&1; then
    setsid bash "$skill_scripts/cloud.sh" sync --quiet </dev/null >/dev/null 2>&1 &
  else
    nohup bash "$skill_scripts/cloud.sh" sync --quiet </dev/null >/dev/null 2>&1 &
  fi
  disown 2>/dev/null || true
fi

# Mark today active (activation ages count active days, not calendar days —
# time away must not decay the store) and prune ancient markers.
touch "$state_base/activity/$(date +%Y-%m-%d)" 2>/dev/null || true
find "$state_base/activity" -mtime +400 -delete 2>/dev/null || true

# Seed the usage baseline the Stop hook's reconciliation check compares against.
usz=0
for u in "$state_personal/usage.log" "$state_team/usage.log" "$state_project/usage.log"; do
  [ -f "$u" ] && usz=$((usz + $(wc -c < "$u")))
done
printf '%s' "$usz" > "$state_base/sessions/$sid.usize" 2>/dev/null || true

journal="$personal/journal/$sid.md"
if [ ! -f "$journal" ]; then
  # Best-effort client identity: capture eagerness varies by harness, and
  # without this field the variance cannot even be counted from the store.
  client="${CLAUDE_CODE_ENTRYPOINT:-${TERM_PROGRAM:-unknown}}"
  printf '<!-- session %s | repo %s | team-staging-root %s | client %s | started %s -->\n' \
    "$sid" "$repo_root" "$teamlocal" "$client" "$(date -Iseconds)" > "$journal"
fi
find "$state_base/sessions" -name '*.hash' -mtime +7 -delete 2>/dev/null || true
touch "$state_base/sessions/$sid.alive" 2>/dev/null || true

rebuild_if_stale() {
  local root="$1" sdir="$2"
  [ -d "$root/prefer" ] || return 0
  # Stale when: no index; an entry changed; usage.log grew (use moves entries
  # between tiers); or a day passed (activation decays with time, not events).
  if [ ! -f "$root/index.md" ] || \
     [ -n "$(find "$root/prefer" -name '*.md' -newer "$root/index.md" -print -quit 2>/dev/null)" ] || \
     { [ -f "$sdir/usage.log" ] && [ "$sdir/usage.log" -nt "$root/index.md" ]; } || \
     [ -n "$(find "$root/index.md" -mtime +1 -print -quit 2>/dev/null)" ]; then
    bash "$skill_scripts/rebuild-index.sh" "$root" "$sdir" 2>/dev/null || true
  fi
}

journal_report() {
  local root="$1" label="$2"
  [ -d "$root/journal" ] || return 0
  local confirmed=0 orphaned=0 cands=0 f jsid alive
  for f in "$root/journal"/*.md; do
    [ -e "$f" ] || continue
    local c p k
    c="$(grep -c '^## confirmed / ' "$f" 2>/dev/null || true)"
    k="$(grep -c '^## candidate / ' "$f" 2>/dev/null || true)"
    p="$(awk '/^<!-- analyzed /{n=0; next} /^- 20[0-9][0-9]-/{n++} END{print n+0}' "$f" 2>/dev/null || true)"
    confirmed=$((confirmed + ${c:-0}))
    cands=$((cands + ${k:-0}))
    # A session is dead when its alive marker is missing or stale (30 min),
    # regardless of journal age — a session that ended a minute ago is fair game.
    jsid="$(basename "$f" .md)"
    alive="$state_base/sessions/$jsid.alive"
    if [ "$jsid" != "$sid" ] && { [ ! -f "$alive" ] || [ -n "$(find "$alive" -mmin +30 -print -quit 2>/dev/null)" ]; }; then
      orphaned=$((orphaned + p))
    fi
  done
  if [ "$confirmed" -gt 0 ] || [ "$orphaned" -gt 0 ] || [ "$cands" -gt 0 ]; then
    echo "- $label scope: $confirmed confirmed block(s), $cands unconsumed candidate(s), and $orphaned unanalyzed raw line(s) from dead sessions. Consolidation (Mode B), candidate elicitation (A3), and analysis (A2) are due before substantive work begins; the journals' provenance headers say where team-scope blocks belong."
  fi
}

emit_index() {
  local root="$1" label="$2"
  [ -f "$root/index.md" ] || return 0
  local body
  body="$(tail -n +2 "$root/index.md")"
  [ -n "$body" ] || return 0
  echo "### $label preferences ($root)"
  echo "$body"
}

deferred_note() {
  local n
  n="$(ls "$personal/deferred"/*.md 2>/dev/null | wc -l | tr -d ' ')"
  [ "${n:-0}" -gt 0 ] && echo "Deferred candidates on file: $n (re-ask each when its topic next comes up live; full receipts inside each file)."
}

rebuild_if_stale "$personal" "$state_personal"
rebuild_if_stale "$teamlocal" "$state_team"
[ -d "$project" ] && rebuild_if_stale "$project" "$state_project"

ctx="$(
  echo "rather-than session context. Session id: $sid. Journal for this session (all raw lines and confirmed blocks, provenance header inside): $personal/journal/$sid.md. Team-scope root (local staging, not committed): $teamlocal. Project root (published): $project."
  echo "State dirs (usage.log, usage-summary.md, consolidation lock per root): personal $state_personal, team $state_team, project $state_project."
  [ -n "$schema_note" ] && echo "$schema_note"
  [ -n "$cloud_note" ] && echo "$cloud_note"
  echo
  echo "The rather-than skill tracks the user's coding preferences as tendencies. Journal duty (every turn): whenever the user steers anything — a directive (plain tasks included), a correction of earlier output, an evaluative remark in passing, a pick among offered options, process steering — or a consistent codebase pattern is noticed, append one natural English sentence to this session's journal, capturing what was chosen instead of what (the rejected side evaporates after the turn), any stated reason, and what was being worked on. Dirty is fine; skip only pure information questions. 'User' in a raw line is reserved for the human: steering that arrives from another model (a parent agent's task prompt, a cross-session message) is recorded with its actual author named, or tagged [author: unverified] when the channel is unclear — analysis never turns non-human steering into a preference. Analysis happens later in batches, never mid-task."
  echo "The indexes below are activation-tiered. 'habitual' entries have earned always-on status through use — apply them within their observed-in contexts; each line carries its Except situations, flagged [N except: …], and never apply an excepted entry without its Excepts in view. 'cold' lines list only category: count (slugs) — cold entries are NOT active constraints: when the current work touches a cold category, consult it first with bash \"$skill_scripts/query.sh\" <root> -c <category> (default projection: topic, observed-in, Except; -s <slug> and -f <fields> also work); applying a cold entry unconsulted is a misfire. Use moves entries between tiers: applied/excepted/overridden events logged to the state-dir usage.log are what promote, demote, and decay entries, so a missed log line now also weakens injection. Full files at <root>/prefer/<slug>.md hold Except reasons and evidence. Tendencies never block the user. The skill's Mode A covers capture, Mode B consolidation."
  deferred_note
  emit_index "$personal" "Personal"
  emit_index "$teamlocal" "Team (local staging, not committed)"
  [ -d "$project" ] && emit_index "$project" "Project (published, committed)"
  report_p="$(journal_report "$personal" "personal")"
  report_t=""
  if [ -n "$report_p$report_t" ]; then
    echo
    echo "### Pending consolidation"
    [ -n "$report_p" ] && echo "$report_p"
    [ -n "$report_t" ] && echo "$report_t"
  fi
)"

# Seed the per-session hash before emitting, so truncated output can't cause loops.
idx_hash="$(cat "$personal/index.md" "$teamlocal/index.md" "$project/index.md" 2>/dev/null | sha256sum | cut -d' ' -f1)"
printf '%s' "$idx_hash" > "$state_base/sessions/$sid.hash" 2>/dev/null || true
cat "$personal/index.md" "$teamlocal/index.md" "$project/index.md" 2>/dev/null > "$state_base/sessions/$sid.index" || true

if command -v jq >/dev/null 2>&1; then
  jq -nc --arg ctx "$ctx" \
    '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'
else
  echo "$ctx"
fi

exit 0
