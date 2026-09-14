#!/usr/bin/env bash
# 001 — move execution state out of the installed skill into <store>/.state/
# Since 7b59ed7 (2026-08-25). Sourced by scripts/init.sh; contract in README.md.
#
# Schema 0 kept usage logs, session markers, the consolidation locks and
# elicitation.log at ~/.claude/skills/rather-than/.state/ — inside the
# installed skill, where a skills-CLI update replaces them. 7b59ed7 moved
# the state to <store>/.state/ but left the old directory behind, so every
# applied/overridden event and every elicitation answer from before the
# move stopped counting. This merges the old tree into the new one:
#   - a file the new tree lacks is moved;
#   - a .log present on both sides is concatenated, duplicate lines dropped;
#   - any other collision keeps the store's copy and parks the old file
#     under <store>/.state/legacy-conflicts/<same path> for a human.
# Nothing is deleted except directories left empty.

MIG_SINCE=7b59ed7
MIG_DATE=2026-08-25
MIG_TITLE="move execution state out of the installed skill into <store>/.state/"

m001_legacy="$HOME/.claude/skills/rather-than/.state"

m001_same_dir() { # true when the legacy dir IS the store's state dir (symlinked)
  [ -d "$m001_legacy" ] && [ -d "$STATE" ] &&
    [ "$(cd "$m001_legacy" && pwd -P)" = "$(cd "$STATE" && pwd -P)" ]
}

# m001_walk <src> <dst> <plan|apply>
m001_walk() {
  local src="$1" dst="$2" mode="$3" item name rel
  for item in "$src"/* "$src"/.[!.]*; do
    [ -e "$item" ] || continue
    name="$(basename "$item")"
    rel="${item#"$m001_legacy"/}"
    if [ -d "$item" ]; then
      [ "$mode" = apply ] && mkdir -p "$dst/$name"
      m001_walk "$item" "$dst/$name" "$mode"
    elif [ ! -e "$dst/$name" ]; then
      say "move $rel"
      if [ "$mode" = apply ]; then mkdir -p "$dst"; mv "$item" "$dst/$name"; fi
    else
      case "$name" in
        *.log)
          say "merge $rel (append the lines the store's log lacks)"
          if [ "$mode" = apply ]; then
            awk 'FNR==NR{seen[$0]=1; next} !seen[$0]' "$dst/$name" "$item" >> "$dst/$name"
            rm -f "$item"
          fi ;;
        *)
          say "park $rel under .state/legacy-conflicts/ (both sides exist; the store's copy is kept)"
          if [ "$mode" = apply ]; then
            mkdir -p "$STATE/legacy-conflicts/$(dirname "$rel")"
            mv "$item" "$STATE/legacy-conflicts/$rel"
          fi ;;
      esac
    fi
  done
  return 0
}

mig_plan() {
  [ -d "$m001_legacy" ] || return 0
  m001_same_dir && return 0
  local out
  out="$(m001_walk "$m001_legacy" "$STATE" plan)"
  if [ -n "$out" ]; then printf '%s\n' "$out"; else say "remove the empty legacy state dir $m001_legacy"; fi
}

mig_apply() {
  [ -d "$m001_legacy" ] || return 0
  m001_same_dir && return 0
  mkdir -p "$STATE"
  m001_walk "$m001_legacy" "$STATE" apply
  find "$m001_legacy" -depth -type d -empty -delete 2>/dev/null || true
  [ -d "$m001_legacy" ] && say "left in place (still holds files): $m001_legacy"
  return 0
}
