#!/usr/bin/env bash
# Stop hook for rather-than: at each response end, at most ONE block, for the
# first of two reasons that applies (both rate-limited per session):
# 1) consolidation — confirmed blocks are waiting, so run Mode B at this
#    natural break point instead of never;
# 2) usage reconciliation — this response edited files, habitual-tier entries
#    exist, and not one usage event was logged, so the tier bookkeeping (which
#    the model reliably forgets mid-task) happens now, at the break point.
#    The hook cannot judge WHICH tendencies applied — it can only detect the
#    shape of the absence and force the moment the model decides.
# Session start remains the crash safety net.
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

. "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/paths.sh"

sid="$(get_field session_id)"; [ -n "$sid" ] || sid="unknown-$$"
cwd="$(get_field cwd)"; [ -n "$cwd" ] || cwd="$PWD"
store="$(rt_store_root)"
state_base="$store/.state"
journals="$store/journal"
mkdir -p "$state_base/sessions"

# --- 1) consolidation nudge -------------------------------------------------
n="$(grep -h -c '^## confirmed / ' "$journals"/*.md 2>/dev/null | awk '{s+=$1} END{print s+0}')"
if [ "${n:-0}" -gt 0 ]; then
  nudge="$state_base/sessions/$sid.nudge"
  if [ ! -f "$nudge" ] || [ -n "$(find "$nudge" -mmin +30 -print -quit 2>/dev/null)" ]; then
    touch "$nudge"
    reason="rather-than: $n confirmed preference block(s) await consolidation and this response just ended at a natural break point. Run Mode B now: read the journals under $journals, take the per-root consolidation locks, apply the confirmed blocks to their prefer/ stores (route team-scope blocks by each journal's provenance header), rebuild indexes, delete the processed journals, release the locks. Then finish."
    printf '{"decision": "block", "reason": "%s"}\n' "$reason"
    exit 0
  fi
fi

# --- 2) usage reconciliation nudge ------------------------------------------
# Resolve this session's roots the same way the other hooks do.
repo_root="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$repo_root" ] || repo_root="$cwd"
repo_key="$(basename "$repo_root")-$(printf '%s' "$repo_root" | sha256sum | cut -c1-8)"
teamlocal="$store/team/$repo_key"
project="$(rt_project_root "$repo_root")"

# Only worth nudging when something is actually in the habitual tier.
hab=0
for idx in "$store/index.md" "$teamlocal/index.md" "$project/index.md"; do
  grep -q '^## habitual' "$idx" 2>/dev/null && { hab=1; break; }
done
[ "$hab" -eq 1 ] || exit 0

# Did any usage.log grow since the last check? Growth = reconciled = clean.
usize_now=0
for u in "$state_base/personal/usage.log" "$state_base/team-$repo_key/usage.log" "$state_base/project-$repo_key/usage.log"; do
  [ -f "$u" ] && usize_now=$((usize_now + $(wc -c < "$u")))
done
usize_f="$state_base/sessions/$sid.usize"
tsoff_f="$state_base/sessions/$sid.tsoffset"
if [ ! -f "$usize_f" ]; then
  # No baseline (session predates this hook, or session-start did not run):
  # seed and stay silent — the next stop can tell growth from silence.
  printf '%s' "$usize_now" > "$usize_f" 2>/dev/null || true
  exit 0
fi
if [ "$usize_now" -gt "$(cat "$usize_f" 2>/dev/null || echo 0)" ]; then
  printf '%s' "$usize_now" > "$usize_f" 2>/dev/null || true
  tp="$(get_field transcript_path)"
  [ -n "$tp" ] && [ -f "$tp" ] && printf '%s' "$(wc -c < "$tp")" > "$tsoff_f" 2>/dev/null || true
  exit 0
fi

# Did this response (transcript since our offset) edit any files? Unreadable
# transcript (a harness with a different format) degrades to no nudge.
tp="$(get_field transcript_path)"
{ [ -n "$tp" ] && [ -f "$tp" ]; } || exit 0
size="$(wc -c < "$tp")"
off="$(cat "$tsoff_f" 2>/dev/null || echo 0)"
case "$off" in ''|*[!0-9]*) off=0;; esac
[ "$size" -gt "$off" ] || exit 0
edits="$(tail -c +$((off + 1)) "$tp" | grep -c -E '"name":[[:space:]]*"(Edit|Write|MultiEdit|NotebookEdit)"' || true)"
if [ "${edits:-0}" -eq 0 ]; then
  printf '%s' "$size" > "$tsoff_f" 2>/dev/null || true
  exit 0
fi

# Rate limit; when limited, keep the offset so the pending edits still count
# at the next eligible stop.
unudge="$state_base/sessions/$sid.unudge"
if [ -f "$unudge" ] && [ -z "$(find "$unudge" -mmin +30 -print -quit 2>/dev/null)" ]; then
  exit 0
fi
touch "$unudge"
printf '%s' "$size" > "$tsoff_f" 2>/dev/null || true

reason="rather-than: this response edited files and no usage event was logged this session. Reconcile now against the habitual entries in the injected indexes: for each entry the edited code actually engaged, append one line to that root's state-dir usage.log — '<YYYY-MM-DD> <slug> applied', 'excepted match=<which>', or 'overridden reason=<why>' — one bash append per event. Entries the work did not touch get no line. If nothing applied, finish without logging — but decide that explicitly. Then finish."
printf '{"decision": "block", "reason": "%s"}\n' "$reason"
exit 0
