#!/usr/bin/env bash
# 004 — rebuild flat indexes in the activation-tiered format
# Since e4e29d1 (2026-09-10); the index line format also changed at 21e2afc.
# Sourced by scripts/init.sh; contract in README.md.
#
# index.md is derived from prefer/ and the root's usage.log, so the
# migration is a rebuild with the state dir the new script expects. The
# hooks rebuild on their own only when an entry changed, the usage log grew,
# or a day passed — an index written by the old script minutes before the
# upgrade would otherwise stay flat until then. A flat index has category
# headings (`#### …`) but no tier headings (`## habitual`, `## cold`).

MIG_SINCE=e4e29d1
MIG_DATE=2026-09-10
MIG_TITLE="rebuild flat indexes in the activation-tiered format"

m004_flat() { # <root> → true when entries exist and the index is missing or flat
  local root="$1"
  [ -d "$root/prefer" ] || return 1
  [ -n "$(find "$root/prefer" -maxdepth 1 -name '*.md' -print -quit 2>/dev/null)" ] || return 1
  [ -f "$root/index.md" ] || return 0
  ! grep -q '^## ' "$root/index.md"
}

m004_each() { # <plan|apply>
  local root
  while IFS= read -r root; do
    [ -n "$root" ] || continue
    m004_flat "$root" || continue
    say "rebuild $root/index.md"
    [ "$1" = apply ] && bash "$SCRIPTS/rebuild-index.sh" "$root" "$(state_for_root "$root")"
  done <<< "$ROOTS"
  return 0
}

mig_plan()  { m004_each plan; }
mig_apply() { m004_each apply; }
