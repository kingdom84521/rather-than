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


mkdir -p "$personal/prefer" "$personal/journal" "$teamlocal/prefer" "$state_base/sessions" "$state_personal" "$state_team"

journal="$personal/journal/$sid.md"
if [ ! -f "$journal" ]; then
  printf '<!-- session %s | repo %s | team-staging-root %s | started %s -->\n' \
    "$sid" "$repo_root" "$teamlocal" "$(date -Iseconds)" > "$journal"
fi
find "$state_base/sessions" -name '*.hash' -mtime +7 -delete 2>/dev/null || true
touch "$state_base/sessions/$sid.alive" 2>/dev/null || true

rebuild_if_stale() {
  local root="$1"
  [ -d "$root/prefer" ] || return 0
  if [ ! -f "$root/index.md" ] || \
     [ -n "$(find "$root/prefer" -name '*.md' -newer "$root/index.md" -print -quit 2>/dev/null)" ]; then
    bash "$skill_scripts/rebuild-index.sh" "$root" 2>/dev/null || true
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

rebuild_if_stale "$personal"
rebuild_if_stale "$teamlocal"
[ -d "$project" ] && rebuild_if_stale "$project"

ctx="$(
  echo "rather-than session context. Session id: $sid. Journal for this session (all raw lines and confirmed blocks, provenance header inside): $personal/journal/$sid.md. Team-scope root (local staging, not committed): $teamlocal. Project root (published): $project."
  echo "State dirs (usage.log, usage-summary.md, consolidation lock per root): personal $state_personal, team $state_team, project $state_project."
  echo
  echo "The rather-than skill tracks the user's coding preferences as tendencies. Journal duty (every turn): whenever the user steers anything — a directive (plain tasks included), a correction of earlier output, an evaluative remark in passing, a pick among offered options, process steering — or a consistent codebase pattern is noticed, append one natural English sentence to this session's journal, capturing what was chosen instead of what (the rejected side evaporates after the turn), any stated reason, and what was being worked on. Dirty is fine; skip only pure information questions. Analysis happens later in batches, never mid-task. The indexes below list recorded preferences grouped by category; full entries (Except clauses, observed-in scopes) live at <root>/prefer/<slug>.md — entries flagged [N except] must be read before use, and tendencies apply only within their observed-in contexts. Tendencies never block the user; applied/excepted/overridden events go to the state-dir usage.log. The skill's Mode A covers capture, Mode B consolidation."  echo
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
