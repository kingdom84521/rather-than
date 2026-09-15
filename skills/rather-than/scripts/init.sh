#!/usr/bin/env bash
# init.sh — bring a rather-than store up to the layout this plugin version expects.
#
# The store's layout has changed several times (state dir moved, journal
# header and candidate blocks grew a field, the index became tiered, the
# activation clock started counting active days). Each change ships as one
# numbered file under ../migrations/, written when the change was made and
# never derived here. This script decides only two things: WHICH of those
# files still apply — the store's schema marker against the highest id
# shipped — and HOW they run: plan only, or apply after a backup, stopping
# at a chosen id. A migration that needs judgment rather than file work
# hands its instructions to <store>/.state/migrations.todo.md for the model
# to work through with the user; the mechanical part still runs here.
#
# Usage: init.sh [--yes] [--target N] [--store PATH] [--repo PATH] [--prune]
#   (no flags)   plan: store, schema have/expected, one line per pending
#                action, leftovers from older install routes. No writes.
#                Exit 0 when up to date, 10 when migrations are pending.
#   --yes        apply the pending migrations in order, after a tarball
#                backup under <store>/.state/backups/; the marker advances
#                after each one, so a failed run resumes where it stopped.
#   --target N   stop after migration N.
#   --store P    store root; default: the same resolution the hooks use.
#   --repo P     repo whose project root joins the run; default: cwd's git root.
#   --prune      also remove stale skill copies left by an older install
#                route (otherwise reported with the command to run).
set -uo pipefail

here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
SCRIPTS="$here"
SKILL_DIR="${here%/scripts}"
MIG_DIR="$SKILL_DIR/migrations"

usage() { sed -n '2,/^set -uo/p' "${BASH_SOURCE[0]}" | sed '$d; s/^# \{0,1\}//' >&2; exit 2; }

APPLY=0 TARGET="" STORE_OPT="" REPO_OPT="" PRUNE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --yes|-y) APPLY=1 ;;
    --target) TARGET="${2:?--target needs a number}"; shift ;;
    --store)  STORE_OPT="${2:?--store needs a path}"; shift ;;
    --repo)   REPO_OPT="${2:?--repo needs a path}"; shift ;;
    --prune)  PRUNE=1 ;;
    -h|--help) usage ;;
    *) echo "unknown option: $1" >&2; usage ;;
  esac
  shift
done

say()   { printf '  - %s\n' "$*"; }
head_() { printf '%s\n' "$*"; }

# --- path resolution: mirrors hooks/rather-than/paths.sh. The hooks are not
# guaranteed to sit beside this script (skills-CLI route), so it is inlined,
# the way query.sh inlines it.
canon() { (cd "$1" 2>/dev/null && pwd -P) || printf '%s' "$1"; }
rt_store() {
  if [ -n "${RATHER_THAN_HOME:-}" ]; then printf '%s' "$RATHER_THAN_HOME"
  elif [ -d "$HOME/.claude/rather-than" ]; then printf '%s' "$HOME/.claude/rather-than"
  else printf '%s' "${XDG_DATA_HOME:-$HOME/.local/share}/rather-than"; fi
}
rt_project_root() {
  if [ -d "$1/.claude/rather-than" ]; then printf '%s' "$1/.claude/rather-than"; else printf '%s' "$1/.rather-than"; fi
}

STORE="$(canon "${STORE_OPT:-$(rt_store)}")"
STATE="$STORE/.state"

repo_root="${REPO_OPT:-$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || true)}"
[ -n "$repo_root" ] && repo_root="$(canon "$repo_root")"
repo_key=""; project=""
if [ -n "$repo_root" ]; then
  repo_key="$(basename "$repo_root")-$(printf '%s' "$repo_root" | sha256sum | cut -c1-8)"
  project="$(rt_project_root "$repo_root")"
fi

ROOTS="$STORE"
for t in "$STORE"/team/*/; do [ -d "$t" ] && ROOTS="$ROOTS"$'\n'"${t%/}"; done
[ -n "$project" ] && [ -d "$project" ] && ROOTS="$ROOTS"$'\n'"$project"

state_for_root() { # <root> → its state dir (same derivation as the hooks and query.sh)
  local r key repo
  r="$(canon "$1")"
  case "$r" in
    "$STORE") printf '%s' "$STATE/personal" ;;
    "$STORE"/team/*)
      key="${r#"$STORE"/team/}"; key="${key%%/*}"; printf '%s' "$STATE/team-$key" ;;
    */.claude/rather-than | */.rather-than)
      repo="${r%/.claude/rather-than}"; repo="${repo%/.rather-than}"
      key="$(basename "$repo")-$(printf '%s' "$repo" | sha256sum | cut -c1-8)"
      printf '%s' "$STATE/project-$key" ;;
    *) printf '%s' "$STATE/other-$(printf '%s' "$r" | sha256sum | cut -c1-8)" ;;
  esac
}
export STORE STATE ROOTS SCRIPTS

# --- schema: have vs shipped ------------------------------------------------
mig_files="$(ls "$MIG_DIR"/[0-9][0-9][0-9]-*.sh 2>/dev/null | sort)"
if [ -z "$mig_files" ]; then echo "no migrations directory at $MIG_DIR — is this a complete skill copy?" >&2; exit 2; fi
latest="$(printf '%s\n' "$mig_files" | tail -n 1 | sed 's#.*/\([0-9][0-9][0-9]\)-.*#\1#')"; latest=$((10#$latest))
have="$(cat "$STATE/schema" 2>/dev/null || echo 0)"
case "$have" in ''|*[!0-9]*) have=0 ;; esac
target="${TARGET:-$latest}"
case "$target" in ''|*[!0-9]*) echo "--target must be a number" >&2; exit 2 ;; esac
[ "$target" -gt "$latest" ] && target="$latest"

case "$SKILL_DIR" in */plugins/*) route="plugin" ;; *) route="skills-cli" ;; esac

head_ "rather-than init"
head_ "  store    $STORE$([ -d "$STORE" ] || printf ' (not created yet)')"
if [ "$have" -ge "$latest" ]; then head_ "  schema   $have (up to date)"; else head_ "  schema   $have → $target of $latest shipped"; fi
head_ "  roots    $(printf '%s\n' "$ROOTS" | wc -l | tr -d ' ') — personal$([ -n "$project" ] && [ -d "$project" ] && printf ', project %s' "$project")$(n=$(ls -d "$STORE"/team/*/ 2>/dev/null | wc -l | tr -d ' '); [ "$n" -gt 0 ] && printf ', team ×%s' "$n")"
head_ "  skill    $SKILL_DIR ($route route)"
head_ ""

# --- plan every pending migration ---------------------------------------------
pending_ids=(); pending_plans=(); any_pending=0; plan_failed=0
while IFS= read -r f; do
  id=$((10#$(basename "$f" | cut -c1-3)))
  [ "$id" -gt "$have" ] && [ "$id" -le "$target" ] || continue
  unset -f mig_plan mig_apply mig_semantic 2>/dev/null
  MIG_SINCE="?"; MIG_DATE="?"; MIG_TITLE="$(basename "$f")"
  # shellcheck disable=SC1090
  . "$f"
  head_ "$(printf '%03d' "$id") $MIG_SINCE  $MIG_TITLE"
  if plan="$( set -e; mig_plan 2>&1 )"; then
    if [ -n "$plan" ]; then printf '%s\n' "$plan"; any_pending=1; else say "nothing to do"; fi
  else
    printf '%s\n' "$plan"; say "PLAN FAILED — fix before applying"; plan_failed=1
  fi
  pending_ids+=("$id"); pending_plans+=("$plan")
done <<< "$mig_files"

# --- leftovers from an older install route ------------------------------------
leftovers=()
if [ "$route" = plugin ]; then
  for d in "$HOME/.claude/skills/rather-than" "$HOME/.agents/skills/rather-than" "${CODEX_HOME:-$HOME/.codex}/skills/rather-than"; do
    [ -d "$d" ] || continue
    [ "$(canon "$d")" = "$(canon "$SKILL_DIR")" ] && continue
    leftovers+=("$d")
  done
fi
hand_hooks="$HOME/.claude/hooks/rather-than"
settings_refs=0
[ -f "$HOME/.claude/settings.json" ] && grep -q 'hooks/rather-than/' "$HOME/.claude/settings.json" 2>/dev/null && settings_refs=1

if [ "${#leftovers[@]}" -gt 0 ] || { [ "$route" = plugin ] && [ -d "$hand_hooks" ]; }; then
  head_ ""
  head_ "leftovers from the skills-CLI route (the plugin route is active)"
  for d in "${leftovers[@]}"; do
    if [ -d "$d/.state" ]; then
      say "stale skill copy $d — still holds a .state/ dir; migration 001 moves it out, then --prune removes the copy"
    else
      say "stale skill copy $d — the hooks resolve the plugin's copy first, so this one is never read$([ "$PRUNE" = 1 ] && printf '; removing' || printf '; remove with --prune')"
    fi
  done
  if [ "$route" = plugin ] && [ -d "$hand_hooks" ]; then
    if [ "$settings_refs" = 1 ]; then
      say "hand-registered hooks in ~/.claude/settings.json point at $hand_hooks — they fire alongside the plugin's, so every injection happens twice. Remove those entries (this script never edits settings.json), e.g.:"
      printf '      jq %s ~/.claude/settings.json > /tmp/settings.json && mv /tmp/settings.json ~/.claude/settings.json\n' \
        "'.hooks |= with_entries(.value |= map(select(((.hooks // []) | any((.command // \"\") | test(\"hooks/rather-than/\"))) | not)))'"
      say "then delete $hand_hooks"
    else
      say "hook copies at $hand_hooks are not registered anywhere$([ "$PRUNE" = 1 ] && printf '; removing' || printf '; remove with --prune')"
    fi
  fi
fi

# --- notes: honored legacy locations, nothing to move --------------------------
notes=()
[ "$STORE" = "$(canon "$HOME/.claude/rather-than")" ] && notes+=("store is at the pre-7b59ed7 location ~/.claude/rather-than — still honored, nothing to move")
[ -n "$project" ] && [ -d "$project" ] && case "$project" in */.claude/rather-than) notes+=("project root is at the pre-7b59ed7 location $project — still honored; new repos use <repo>/.rather-than") ;; esac
[ -s "$STATE/migrations.todo.md" ] && notes+=("semantic migration steps await in $STATE/migrations.todo.md — work them through at the next Mode B")
if [ "${#notes[@]}" -gt 0 ]; then head_ ""; head_ "notes"; for n in "${notes[@]}"; do say "$n"; done; fi

# --- decide --------------------------------------------------------------------
head_ ""
if [ "$plan_failed" = 1 ]; then head_ "A plan failed; nothing was changed."; exit 1; fi

if [ "$APPLY" = 0 ]; then
  if [ "$have" -ge "$target" ] && [ "$any_pending" = 0 ]; then
    if [ ! -f "$STATE/schema" ] && [ ! -d "$STORE/prefer" ]; then
      head_ "No store yet. The first session creates it and stamps schema $latest; nothing to do here."
    else
      head_ "Up to date. Nothing to do."
    fi
    exit 0
  fi
  head_ "Plan only. Apply with: bash \"${BASH_SOURCE[0]}\" --yes$([ -n "$TARGET" ] && printf ' --target %s' "$TARGET")"
  exit 10
fi

# --- apply ---------------------------------------------------------------------
mkdir -p "$STATE"
ts="$(date +%Y%m%dT%H%M%S)"

# Serialize against consolidation: the same locks Mode B takes.
locked=()
release_all() { local s; for s in "${locked[@]}"; do bash "$SCRIPTS/consolidate-lock.sh" release "$s" 2>/dev/null || true; done; }
trap release_all EXIT
while IFS= read -r root; do
  [ -n "$root" ] || continue
  s="$(state_for_root "$root")"
  if bash "$SCRIPTS/consolidate-lock.sh" acquire "$s" 2>/dev/null; then locked+=("$s"); else
    head_ "Another session holds the consolidation lock for $root. Nothing was changed; retry when it finishes."; exit 1
  fi
done <<< "$ROOTS"

if [ "$any_pending" = 1 ]; then
  mkdir -p "$STATE/backups"
  bk="$STATE/backups/pre-init-$ts.tgz"
  members=("${STORE#/}")
  [ -d "$HOME/.claude/skills/rather-than/.state" ] && members+=("${HOME#/}/.claude/skills/rather-than/.state")
  [ -n "$project" ] && [ -d "$project" ] && members+=("${project#/}")
  # cloud.conf holds credentials and .state/cloud is rebuildable sync state: neither belongs in a 644 tarball.
  if tar -czf "$bk" -C / --exclude="${STORE#/}/.state/backups" --exclude="${STORE#/}/.state/cloud" --exclude="${STORE#/}/cloud.conf" "${members[@]}" 2>/dev/null; then
    chmod 600 "$bk" 2>/dev/null || true
    head_ "backup   $bk"
  else
    head_ "Backup failed ($bk); nothing was changed."; exit 1
  fi
fi

i=0
for id in "${pending_ids[@]}"; do
  plan="${pending_plans[$i]}"; i=$((i + 1))
  f="$(printf '%s\n' "$mig_files" | grep "/$(printf '%03d' "$id")-")"
  unset -f mig_plan mig_apply mig_semantic 2>/dev/null
  # shellcheck disable=SC1090
  . "$f"
  if [ -z "$plan" ]; then
    printf '%s %03d noop %s\n' "$(date -Iseconds)" "$id" "$MIG_TITLE" >> "$STATE/migrations.log"
    printf '%s' "$id" > "$STATE/schema"
    continue
  fi
  head_ "$(printf '%03d' "$id") applying"
  if ( set -e; mig_apply ); then
    if declare -F mig_semantic >/dev/null 2>&1; then
      { printf '## %03d — %s\n\n' "$id" "$MIG_TITLE"; ( mig_semantic ); printf '\n'; } >> "$STATE/migrations.todo.md"
      say "semantic remainder written to $STATE/migrations.todo.md"
    fi
    printf '%s %03d applied %s\n' "$(date -Iseconds)" "$id" "$MIG_TITLE" >> "$STATE/migrations.log"
    printf '%s' "$id" > "$STATE/schema"
  else
    printf '%s %03d FAILED %s\n' "$(date -Iseconds)" "$id" "$MIG_TITLE" >> "$STATE/migrations.log"
    head_ "$(printf '%03d' "$id") failed; schema stays at $(cat "$STATE/schema" 2>/dev/null || echo 0). Backup: ${bk:-none}. Fix and rerun."
    exit 1
  fi
done

if [ "$PRUNE" = 1 ]; then
  for d in "${leftovers[@]}"; do
    if [ -d "$d/.state" ]; then say "kept $d — its .state/ still holds files (see migration 001's report)"; else rm -rf "$d"; say "removed $d"; fi
  done
  if [ "$route" = plugin ] && [ -d "$hand_hooks" ] && [ "$settings_refs" = 0 ]; then rm -rf "$hand_hooks"; say "removed $hand_hooks"; fi
fi

head_ ""
head_ "schema   $(cat "$STATE/schema")$([ "$(cat "$STATE/schema")" -ge "$latest" ] && printf ' (up to date)')"
exit 0
