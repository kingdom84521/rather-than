#!/usr/bin/env bash
# Stop hook for rather-than: at each response end, if confirmed blocks are
# waiting, block the stop ONCE (rate-limited) so the model runs Mode B at
# this natural break point. Session start remains the crash safety net.
set -uo pipefail

input="$(cat)"

get_field() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$input" | jq -r ".$1 // empty" 2>/dev/null
  else
    printf '%s' "$input" | sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -n1
  fi
}

# Never re-block a continuation triggered by a stop hook (loop guard).
if printf '%s' "$input" | grep -q '"stop_hook_active"[[:space:]]*:[[:space:]]*true'; then
  exit 0
fi

sid="$(get_field session_id)"; [ -n "$sid" ] || sid="unknown-$$"
state_base="$HOME/.claude/skills/rather-than/.state"
journals="$HOME/.claude/rather-than/journal"

n="$(grep -h -c '^## confirmed / ' "$journals"/*.md 2>/dev/null | awk '{s+=$1} END{print s+0}')"
[ "${n:-0}" -gt 0 ] || exit 0

# Rate limit: nudge at most once per 30 minutes per session.
mkdir -p "$state_base/sessions"
nudge="$state_base/sessions/$sid.nudge"
if [ -f "$nudge" ] && [ -z "$(find "$nudge" -mmin +30 -print -quit 2>/dev/null)" ]; then
  exit 0
fi
touch "$nudge"

reason="rather-than: $n confirmed preference block(s) await consolidation and this response just ended at a natural break point. Run Mode B now: read the journals under ~/.claude/rather-than/journal/, take the per-root consolidation locks, apply the confirmed blocks to their prefer/ stores (route team-scope blocks by each journal's provenance header), rebuild indexes, delete the processed journals, release the locks. Then finish."
printf '{"decision": "block", "reason": "%s"}\n' "$reason"
exit 0
