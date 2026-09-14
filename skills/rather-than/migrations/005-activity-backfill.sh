#!/usr/bin/env bash
# 005 — backfill active-day markers from recorded history, then rebuild
# Since e6953c6 (2026-09-10). Sourced by scripts/init.sh; contract in README.md.
#
# e6953c6 made activation age count ACTIVE days — days the hooks saw the
# store in use, recorded as <store>/.state/activity/<YYYY-MM-DD> — instead
# of calendar days, so time away does not cool the store. The hooks only
# start writing markers on upgrade day. With one marker on file, every
# older event counts as one active day old, every entry scores as if used
# yesterday, and the habitual/cold split is wrong until months of real
# markers accumulate.
#
# The store already knows which days it was used: usage.log and
# elicitation.log dates, journal raw-line dates and session start dates,
# analysis markers, Evidence and `created` dates in prefer/ entries,
# deferred-file dates. Every such day inside the hooks' 400-day retention
# window gets a marker, with its mtime set to that day so the hooks' age
# pruning treats it like one they wrote. Then every root's index is
# rebuilt, because the clock its tiers were computed on has changed. The
# .usize session files and the `consulted` verb from the same commit are
# additive and need nothing.

MIG_SINCE=e6953c6
MIG_DATE=2026-09-10
MIG_TITLE="backfill active-day markers from recorded history, then rebuild the indexes"

m005_legacy="$HOME/.claude/skills/rather-than/.state"   # read too, in case 001 has not run yet

m005_dates() { # every day the store shows signs of use, one YYYY-MM-DD per line, unique
  local root
  {
    cat "$STATE"/*/usage.log "$m005_legacy"/*/usage.log 2>/dev/null | awk '{print $1}' || true
    cat "$STATE/elicitation.log" "$m005_legacy/elicitation.log" 2>/dev/null | awk '{print $1}' || true
    while IFS= read -r root; do
      [ -n "$root" ] && [ -d "$root/prefer" ] || continue
      awk '/^created:/ {print $2}
           /^## Evidence/ {f = 1; next} /^## / {f = 0}
           f && $1 == "-" {print $2}' "$root"/prefer/*.md 2>/dev/null || true
    done <<< "$ROOTS"
    awk '/^- 20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]/ {print substr($2, 1, 10)}
         /^<!-- session / {for (i = 1; i <= NF; i++) if ($i == "started") print substr($(i + 1), 1, 10)}
         /^<!-- analyzed / {print substr($3, 1, 10)}' "$STORE"/journal/*.md 2>/dev/null || true
    awk '/^deferred:/ {print $2}
         /^- 20[0-9][0-9]-/ {print substr($2, 1, 10)}' "$STORE"/deferred/*.md 2>/dev/null || true
  } | grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' | sort -u || true
}

m005_missing() { # dates inside the retention window that have no marker yet
  local today floor d
  today="$(date +%Y-%m-%d)"
  floor="$(date -d '400 days ago' +%Y-%m-%d 2>/dev/null || date -v-400d +%Y-%m-%d 2>/dev/null || echo 0000-00-00)"
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    [[ "$d" > "$today" ]] && continue
    [[ "$d" < "$floor" ]] && continue
    [ -e "$STATE/activity/$d" ] || printf '%s\n' "$d"
  done < <(m005_dates)
}

m005_roots_with_entries() {
  local root
  while IFS= read -r root; do
    [ -n "$root" ] && [ -d "$root/prefer" ] || continue
    [ -n "$(find "$root/prefer" -maxdepth 1 -name '*.md' -print -quit 2>/dev/null)" ] && printf '%s\n' "$root"
  done <<< "$ROOTS"
  return 0
}

mig_plan() {
  local missing n first last k
  missing="$(m005_missing)"
  [ -n "$missing" ] || return 0
  n="$(printf '%s\n' "$missing" | wc -l | tr -d ' ')"
  first="$(printf '%s\n' "$missing" | head -n 1)"
  last="$(printf '%s\n' "$missing" | tail -n 1)"
  say "backfill $n active-day marker(s), $first … $last"
  k="$(m005_roots_with_entries | wc -l | tr -d ' ')"
  [ "$k" -gt 0 ] && say "rebuild $k index(es) on the restored clock"
  return 0
}

mig_apply() {
  local d root n=0
  mkdir -p "$STATE/activity"
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    touch -t "${d//-/}1200" "$STATE/activity/$d" 2>/dev/null || touch "$STATE/activity/$d"
    n=$((n + 1))
  done < <(m005_missing)
  say "backfilled $n active-day marker(s)"
  while IFS= read -r root; do
    [ -n "$root" ] || continue
    bash "$SCRIPTS/rebuild-index.sh" "$root" "$(state_for_root "$root")"
    say "rebuilt $root/index.md"
  done < <(m005_roots_with_entries)
  return 0
}
