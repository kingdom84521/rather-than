#!/usr/bin/env bash
# UserPromptSubmit hook for rather-than.
# Steady-state cost per turn: two `find -newer -quit` probes + one sha256.
# Emits nothing unless the index changed since this session last saw it;
# on change, emits JSON additionalContext (silent injection), plain stdout
# fallback without jq. Must stay well under the 30s UserPromptSubmit timeout.
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

state="$state_base/sessions/$sid.hash"

rebuild_if_stale() {
  local root="$1"
  [ -d "$root/prefer" ] || return 0
  if [ ! -f "$root/index.md" ] || \
     [ -n "$(find "$root/prefer" -name '*.md' -newer "$root/index.md" -print -quit 2>/dev/null)" ]; then
    bash "$skill_scripts/rebuild-index.sh" "$root" 2>/dev/null || true
  fi
}

mkdir -p "$state_base/sessions"
touch "$state_base/sessions/$sid.alive" 2>/dev/null || true

rebuild_if_stale "$personal"
rebuild_if_stale "$teamlocal"
[ -d "$project" ] && rebuild_if_stale "$project"

idx_hash="$(cat "$personal/index.md" "$teamlocal/index.md" "$project/index.md" 2>/dev/null | sha256sum | cut -d' ' -f1)"
prev="$(cat "$state" 2>/dev/null || true)"

reminder="rather-than: journal every steering event from this turn (one English sentence incl. instead-of and working context; plain tasks too). Apply index tendencies within their observed-in scope; never block; log usage events. Full duty spec was injected at session start."

if [ "$idx_hash" = "$prev" ]; then
  if command -v jq >/dev/null 2>&1; then
    jq -nc --arg ctx "$reminder" \
      '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}'
  else
    echo "$reminder"
  fi
  exit 0
fi

emit_index() {
  local root="$1" label="$2"
  [ -f "$root/index.md" ] || return 0
  local body
  body="$(tail -n +2 "$root/index.md")"
  [ -n "$body" ] || return 0
  echo "### $label preferences ($root)"
  echo "$body"
}

# Snapshot diff: inject only what changed, not the whole index.
snap="$state_base/sessions/$sid.index"
cur="$(mktemp)"
cat "$personal/index.md" "$teamlocal/index.md" "$project/index.md" 2>/dev/null > "$cur" || true
if [ -f "$snap" ]; then
  changes="$(diff "$snap" "$cur" 2>/dev/null | grep '^[<>]' | sed 's/^</removed:/; s/^>/added or changed:/' | head -30)"
else
  changes=""
fi

# Write state before emitting so truncated output can't cause repeat injection.
mkdir -p "$state_base/sessions"
printf '%s' "$idx_hash" > "$state" 2>/dev/null || true
cp "$cur" "$snap" 2>/dev/null || true
rm -f "$cur"

ctx="$(
  echo "$reminder"
  echo
  if [ -n "$changes" ]; then
    echo "The preference index changed since this session last read it (possibly a concurrent session). Changed lines:"
    echo "$changes"
    echo "Re-read <root>/index.md for the full picture if needed; full entries live at <root>/prefer/<slug>.md."
  else
    echo "The preference index changed since this session last read it; re-read <root>/index.md before the next code edit."
  fi
)"

if command -v jq >/dev/null 2>&1; then
  jq -nc --arg ctx "$ctx" \
    '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}'
else
  echo "$ctx"
fi

exit 0
