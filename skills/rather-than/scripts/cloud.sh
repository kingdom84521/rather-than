#!/usr/bin/env bash
# cloud.sh — keep the personal store's knowledge files in sync with a remote,
# through a small adapter interface.
#
# What syncs: prefer/*.md, deferred/*.md and ignore.md under the personal
# store — the confirmed knowledge. What never syncs: journal/ (a session's
# working state; its liveness markers are local, so another machine would
# mistake live sessions for dead ones), index.md (derived), .state/ (locks,
# per-machine usage and activity), team/ (keyed by a machine-specific path
# hash), REVIEW.md (transient).
#
# How: a three-way merge per file between the local copy, the remote copy and
# the baseline recorded at the end of the last sync
# (<store>/.state/cloud/baseline.tsv). A file changed on one side only moves to
# the other side, deletions included. A file changed on both sides keeps the
# newer copy in place and the loser under .state/cloud/conflicts/<run>/ — two
# visible deltas, never a silent overwrite, the rule the journals already
# follow. A file deleted on one side and edited on the other keeps the edit.
# A local file deleted because the remote deleted it goes to
# .state/cloud/trash/<run>/ for 30 days.
#
# Adapters live in cloud.d/<name>.sh and implement five functions; the
# contract is in cloud.d/README.md. Shipped: s3 (any S3-compatible endpoint —
# Cloudflare R2, AWS S3, Backblaze B2, MinIO — bash + curl + openssl, no SDK)
# and local (a directory: an NFS mount, a Dropbox or Drive desktop folder, a
# test fixture).
#
# Config: <store>/cloud.conf, `key = value` lines, mode 600 (see `setup`).
# RATHER_THAN_CLOUD_CONFIG overrides the path. RATHER_THAN_CLOUD=off or
# `cloud.sh off` pauses the hooks' background syncs without touching it.
#
# Usage:
#   cloud.sh setup <adapter> [adapter flags] [--yes]
#                    write cloud.conf (prompting for what is missing), check
#                    access, run the first sync; --yes overwrites an existing conf
#   cloud.sh sync [--dry-run] [--quiet]
#                    sync now; the hooks run this in the background
#   cloud.sh status  config (secret masked), last result, conflicts, dry-run plan
#   cloud.sh conflicts   list kept conflict copies
#   cloud.sh off | on    pause / resume the hooks' background syncs
# Exit: 0 done, 1 error, 3 skipped (another sync or a consolidation holds the lock).
set -uo pipefail

here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
ADAPTERS="$here/cloud.d"

QUIET=0
say()  { [ "$QUIET" = 1 ] || printf '%s\n' "$*"; }
warn() { printf 'cloud: %s\n' "$*" >&2; }
die()  { warn "$*"; exit 1; }

# --- store resolution: mirrors hooks/rather-than/paths.sh -------------------
canon() { (cd "$1" 2>/dev/null && pwd -P) || printf '%s' "$1"; }
rt_store() {
  if [ -n "${RATHER_THAN_HOME:-}" ]; then printf '%s' "$RATHER_THAN_HOME"
  elif [ -d "$HOME/.claude/rather-than" ]; then printf '%s' "$HOME/.claude/rather-than"
  else printf '%s' "${XDG_DATA_HOME:-$HOME/.local/share}/rather-than"; fi
}
STORE="$(canon "$(rt_store)")"
STATE="$STORE/.state"
CLOUD="$STATE/cloud"
CONF="${RATHER_THAN_CLOUD_CONFIG:-$STORE/cloud.conf}"
SCRIPTS="$here"

# --- config: `key = value` per line; lines starting with # are comments ------
declare -A CFG=()
cfg_load() {
  [ -f "$1" ] || return 1
  local line k v
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|\#*) continue ;; esac
    case "$line" in *=*) ;; *) continue ;; esac
    k="${line%%=*}"; v="${line#*=}"
    k="${k#"${k%%[![:space:]]*}"}"; k="${k%"${k##*[![:space:]]}"}"
    v="${v#"${v%%[![:space:]]*}"}"; v="${v%"${v##*[![:space:]]}"}"
    case "$v" in \"*\") v="${v#\"}"; v="${v%\"}" ;; \'*\') v="${v#\'}"; v="${v%\'}" ;; esac
    CFG["$k"]="$v"
  done < "$1"
}
cfg() { printf '%s' "${CFG[$1]:-${2:-}}"; }
cfg_write() { # writes CFG in a stable order, secrets last, mode 600
  local tmp="$CONF.tmp.$$" k
  mkdir -p "$(dirname "$CONF")"
  {
    echo "# rather-than cloud sync — $(date -Iseconds)"
    echo "# key = value; lines starting with # are comments; no inline comments."
    for k in adapter provider account_id endpoint region addressing bucket prefix path; do
      [ -n "${CFG[$k]:-}" ] && printf '%s = %s\n' "$k" "${CFG[$k]}"
    done
    for k in "${!CFG[@]}"; do
      case "$k" in adapter|provider|account_id|endpoint|region|addressing|bucket|prefix|path|access_key_id|secret_access_key) ;; *) printf '%s = %s\n' "$k" "${CFG[$k]}" ;; esac
    done
    for k in access_key_id secret_access_key; do
      [ -n "${CFG[$k]:-}" ] && printf '%s = %s\n' "$k" "${CFG[$k]}"
    done
    :
  } > "$tmp" && chmod 600 "$tmp" && mv "$tmp" "$CONF" || die "could not write $CONF"
}

# ask <key> <prompt> [default] [secret]: keep an existing CFG value, else prompt on the tty
ask() {
  local key="$1" prompt="$2" def="${3:-}" secret="${4:-}" v
  [ -n "${CFG[$key]:-}" ] && return 0
  if ! ( : < /dev/tty ) 2>/dev/null; then
    [ -n "$def" ] && { CFG["$key"]="$def"; return 0; }
    die "missing '$key' and no terminal to ask on — pass it as a flag"
  fi
  if [ -n "$secret" ]; then
    printf '%s: ' "$prompt" > /dev/tty; IFS= read -rs v < /dev/tty; printf '\n' > /dev/tty
  else
    printf '%s%s: ' "$prompt" "${def:+ [$def]}" > /dev/tty; IFS= read -r v < /dev/tty
  fi
  v="${v:-$def}"
  [ -n "$v" ] || die "'$key' is required"
  CFG["$key"]="$v"
}

load_adapter() { # <name> [init: 1|0]
  local name="${1:?adapter name}" init="${2:-1}"
  [ -f "$ADAPTERS/$name.sh" ] || die "no adapter '$name' under $ADAPTERS (shipped: $(ls "$ADAPTERS"/*.sh 2>/dev/null | xargs -n1 basename 2>/dev/null | sed 's/\.sh$//' | tr '\n' ' '))"
  # shellcheck disable=SC1090
  . "$ADAPTERS/$name.sh"
  for fn in adapter_setup adapter_check adapter_list adapter_get adapter_put adapter_delete; do
    declare -F "$fn" >/dev/null || die "adapter '$name' does not define $fn"
  done
  if [ "$init" = 1 ] && declare -F adapter_init >/dev/null; then adapter_init; fi
  return 0
}

hash_file() { sha256sum "$1" | cut -c1-64; }
mtime_of()  { stat -c %Y "$1" 2>/dev/null || echo 0; }

# The synced set, relative to the store: ignore.md, prefer/*.md, deferred/*.md.
local_manifest() { # path \t sha256 \t mtime
  local f d
  [ -f "$STORE/ignore.md" ] && printf 'ignore.md\t%s\t%s\n' "$(hash_file "$STORE/ignore.md")" "$(mtime_of "$STORE/ignore.md")"
  for d in prefer deferred; do
    for f in "$STORE/$d"/*.md; do
      [ -f "$f" ] || continue
      printf '%s/%s\t%s\t%s\n' "$d" "$(basename "$f")" "$(hash_file "$f")" "$(mtime_of "$f")"
    done
  done
  return 0
}
in_set() { case "$1" in ignore.md) return 0 ;; prefer/*/*|deferred/*/*) return 1 ;; prefer/*.md|deferred/*.md) return 0 ;; *) return 1 ;; esac; }

# --- locks and cleanup -------------------------------------------------------
# One EXIT trap for the whole run: adapters append scratch paths to CLEANUP
# instead of setting traps of their own.
LOCKED_CLOUD=0 LOCKED_CONSOL=0
CLEANUP=()
release_locks() {
  [ "$LOCKED_CONSOL" = 1 ] && bash "$SCRIPTS/consolidate-lock.sh" release "$STATE/personal" 2>/dev/null
  [ "$LOCKED_CLOUD" = 1 ] && rm -rf "$CLOUD/lock"
  return 0
}
on_exit() { release_locks; [ "${#CLEANUP[@]}" -gt 0 ] && rm -rf "${CLEANUP[@]}"; return 0; }
trap on_exit EXIT
take_locks() {
  mkdir -p "$CLOUD"
  if ! mkdir "$CLOUD/lock" 2>/dev/null; then
    if [ -n "$(find "$CLOUD/lock" -maxdepth 0 -mmin +10 2>/dev/null)" ]; then rm -rf "$CLOUD/lock"; mkdir "$CLOUD/lock" 2>/dev/null || return 1
    else return 1; fi
  fi
  LOCKED_CLOUD=1
  if ! bash "$SCRIPTS/consolidate-lock.sh" acquire "$STATE/personal" 2>/dev/null; then release_locks; LOCKED_CLOUD=0; return 2; fi
  LOCKED_CONSOL=1
  return 0
}

# --- the three-way engine ----------------------------------------------------
do_sync() { # [dry]
  local dry="${1:-}" run ts n_push=0 n_pull=0 n_del=0 n_conf=0 n_err=0 n_same=0
  ts="$(date -Iseconds)"; run="$(date +%Y%m%dT%H%M%S)"
  mkdir -p "$CLOUD"

  local -A LH=() LM=() RT=() RM=() BL=() BT=()
  local p h m t
  while IFS=$'\t' read -r p h m; do [ -n "$p" ] && { LH["$p"]="$h"; LM["$p"]="$m"; }; done < <(local_manifest)
  local rlist
  if ! rlist="$(adapter_list)"; then warn "remote listing failed"; return 1; fi
  while IFS=$'\t' read -r p t m; do [ -n "$p" ] && in_set "$p" && { RT["$p"]="$t"; RM["$p"]="${m:-0}"; }; done <<< "$rlist"
  if [ -f "$CLOUD/baseline.tsv" ]; then
    while IFS=$'\t' read -r p h t; do [ -n "$p" ] && { BL["$p"]="$h"; BT["$p"]="$t"; }; done < "$CLOUD/baseline.tsv"
  fi

  local -A SEEN=(); local paths=()
  for p in "${!LH[@]}" "${!RT[@]}" "${!BL[@]}"; do [ -n "${SEEN[$p]:-}" ] || { SEEN["$p"]=1; paths+=("$p"); }; done
  if [ "${#paths[@]}" -gt 0 ]; then mapfile -t paths < <(printf '%s\n' "${paths[@]}" | LC_ALL=C sort); fi

  local newbase="$CLOUD/baseline.tsv.tmp.$$"; : > "$newbase"
  local conflicts="$CLOUD/conflicts/$run" trash="$CLOUD/trash/$run" tmp
  tmp="$(mktemp)"

  keep()   { printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$newbase"; }
  put_()   { # path → token or fail
    local tok; if tok="$(adapter_put "$1" "$STORE/$1")"; then keep "$1" "${LH[$1]}" "${tok:-?}"; n_push=$((n_push+1)); say "push    $1"; else n_err=$((n_err+1)); warn "push failed: $1"; [ -n "${BL[$1]:-}" ] && keep "$1" "${BL[$1]}" "${BT[$1]}"; fi; }
  get_()   { # path → into place
    if adapter_get "$1" "$tmp"; then mkdir -p "$(dirname "$STORE/$1")"; cp "$tmp" "$STORE/$1"; keep "$1" "$(hash_file "$STORE/$1")" "${RT[$1]}"; n_pull=$((n_pull+1)); say "pull    $1"; else n_err=$((n_err+1)); warn "pull failed: $1"; [ -n "${BL[$1]:-}" ] && keep "$1" "${BL[$1]}" "${BT[$1]}"; fi; }

  for p in "${paths[@]}"; do
    local lh="${LH[$p]:-}" rt="${RT[$p]:-}" bl="${BL[$p]:-}" bt="${BT[$p]:-}" lchg=0 rchg=0
    [ "$lh" != "$bl" ] && lchg=1
    [ "$rt" != "$bt" ] && rchg=1
    if [ $lchg = 0 ] && [ $rchg = 0 ]; then
      [ -n "$lh" ] && keep "$p" "$lh" "$rt"; n_same=$((n_same+1)); continue
    fi
    if [ $lchg = 1 ] && [ $rchg = 0 ]; then
      if [ -n "$lh" ]; then
        if [ -n "$dry" ]; then say "would push    $p"; else put_ "$p"; fi
      else
        if [ -n "$dry" ]; then say "would delete  $p (remote)"; elif adapter_delete "$p"; then n_del=$((n_del+1)); say "delete  $p (remote)"; else n_err=$((n_err+1)); warn "remote delete failed: $p"; keep "$p" "$bl" "$bt"; fi
      fi
      continue
    fi
    if [ $lchg = 0 ] && [ $rchg = 1 ]; then
      if [ -n "$rt" ]; then
        if [ -n "$dry" ]; then say "would pull    $p"; else get_ "$p"; fi
      else
        if [ -n "$dry" ]; then say "would delete  $p (local → trash)"; else mkdir -p "$trash/$(dirname "$p")"; mv "$STORE/$p" "$trash/$p"; n_del=$((n_del+1)); say "delete  $p (local → .state/cloud/trash/$run)"; fi
      fi
      continue
    fi
    # both sides changed since the baseline
    if [ -n "$lh" ] && [ -n "$rt" ]; then
      if [ -n "$dry" ]; then say "CONFLICT      $p (changed on both sides; newer wins, loser kept)"; n_conf=$((n_conf+1)); continue; fi
      if ! adapter_get "$p" "$tmp"; then n_err=$((n_err+1)); warn "pull failed: $p"; continue; fi
      if [ "$(hash_file "$tmp")" = "$lh" ]; then keep "$p" "$lh" "$rt"; n_same=$((n_same+1)); continue; fi
      mkdir -p "$conflicts/$(dirname "$p")"; n_conf=$((n_conf+1))
      if [ "${RM[$p]:-0}" -gt "${LM[$p]:-0}" ]; then
        cp "$STORE/$p" "$conflicts/$p.local"; cp "$tmp" "$STORE/$p"; keep "$p" "$(hash_file "$STORE/$p")" "$rt"; n_pull=$((n_pull+1))
        say "CONFLICT $p — remote is newer and is now in place; your copy kept at .state/cloud/conflicts/$run/$p.local"
      else
        cp "$tmp" "$conflicts/$p.remote"; put_ "$p"
        say "CONFLICT $p — local is newer and was pushed; the remote copy kept at .state/cloud/conflicts/$run/$p.remote"
      fi
    elif [ -n "$lh" ]; then   # edited here, deleted there: the edit wins
      if [ -n "$dry" ]; then say "would push    $p (edited here, deleted remotely)"; else put_ "$p"; fi
    elif [ -n "$rt" ]; then   # deleted here, edited there: the edit wins
      if [ -n "$dry" ]; then say "would pull    $p (deleted here, edited remotely)"; else get_ "$p"; fi
    fi
  done
  rm -f "$tmp"

  if [ -n "$dry" ]; then
    rm -f "$newbase"
    say "plan: $(( ${#paths[@]} - n_same )) change(s), $n_conf conflict(s); nothing written"
    return 0
  fi
  LC_ALL=C sort "$newbase" > "$CLOUD/baseline.tsv" && rm -f "$newbase"
  find "$CLOUD/trash" -mindepth 1 -maxdepth 1 -type d -mtime +30 -exec rm -rf {} + 2>/dev/null
  local result=ok; [ "$n_err" -gt 0 ] && result=error
  printf 'ts=%s result=%s pushed=%s pulled=%s deleted=%s conflicts=%s errors=%s\n' "$ts" "$result" "$n_push" "$n_pull" "$n_del" "$n_conf" "$n_err" > "$CLOUD/last"
  printf '%s %s pushed=%s pulled=%s deleted=%s conflicts=%s errors=%s\n' "$ts" "$result" "$n_push" "$n_pull" "$n_del" "$n_conf" "$n_err" >> "$CLOUD/log"
  # Pulled files carry fresh mtimes, so the hooks' staleness check rebuilds the
  # index on its own; rebuild here too so a session starting right now sees it.
  if [ $((n_pull + n_del)) -gt 0 ]; then bash "$SCRIPTS/rebuild-index.sh" "$STORE" "$STATE/personal" 2>/dev/null || true; fi
  say "synced: pushed $n_push, pulled $n_pull, deleted $n_del, conflicts $n_conf, errors $n_err"
  [ "$n_err" -eq 0 ]
}

# --- commands ----------------------------------------------------------------
cmd_setup() {
  local name="${1:-}"; shift || true
  [ -n "$name" ] || die "usage: cloud.sh setup <adapter> [flags]  (adapters: $(ls "$ADAPTERS"/*.sh | xargs -n1 basename | sed 's/\.sh$//' | tr '\n' ' '))"
  local yes=0 rest=()
  for a in "$@"; do case "$a" in --yes|-y) yes=1 ;; *) rest+=("$a") ;; esac; done
  if [ -f "$CONF" ] && [ "$yes" = 0 ]; then die "$CONF exists — edit it, or rerun with --yes to overwrite"; fi
  CFG=(); CFG[adapter]="$name"
  load_adapter "$name" 0
  adapter_setup "${rest[@]}"
  declare -F adapter_init >/dev/null && adapter_init
  say "checking access…"
  adapter_check || die "access check failed; nothing written"
  cfg_write
  say "wrote $CONF (mode 600)"
  mkdir -p "$CLOUD"; rm -f "$CLOUD/off"
  local rc; take_locks; rc=$?
  [ "$rc" = 0 ] || die "could not take the sync lock (another sync or a consolidation is running); run 'cloud.sh sync' later"
  do_sync
}

cmd_sync() {
  local dry=""
  for a in "$@"; do case "$a" in --dry-run|-n) dry=1 ;; --quiet|-q) QUIET=1 ;; *) die "unknown option $a" ;; esac; done
  cfg_load "$CONF" || { say "no cloud sync configured ($CONF missing); run cloud.sh setup <adapter>"; return 0; }
  if [ -z "$dry" ] && { [ -f "$CLOUD/off" ] || [ "${RATHER_THAN_CLOUD:-}" = off ]; }; then say "cloud sync is paused (cloud.sh on to resume)"; return 0; fi
  load_adapter "$(cfg adapter)"
  if [ -z "$dry" ]; then
    local rc; take_locks; rc=$?
    case "$rc" in 1) say "another sync is running; skipped"; return 3 ;; 2) say "a consolidation holds the personal lock; skipped"; return 3 ;; esac
  fi
  do_sync "$dry"
}

cmd_status() {
  if ! cfg_load "$CONF"; then say "no cloud sync configured — $CONF missing. Set it up with: cloud.sh setup s3  (or write the file by hand, see cloud.d/README.md)"; return 0; fi
  say "config    $CONF"
  local k; for k in adapter provider account_id endpoint region addressing bucket prefix path access_key_id; do [ -n "${CFG[$k]:-}" ] && say "  $k = ${CFG[$k]}"; done
  [ -n "${CFG[secret_access_key]:-}" ] && say "  secret_access_key = ****${CFG[secret_access_key]: -4}"
  if [ -f "$CLOUD/off" ] || [ "${RATHER_THAN_CLOUD:-}" = off ]; then say "paused    yes (cloud.sh on to resume)"; fi
  if [ -f "$CLOUD/last" ]; then say "last sync $(cat "$CLOUD/last")"; else say "last sync never"; fi
  local nconf; nconf="$(find "$CLOUD/conflicts" -type f 2>/dev/null | wc -l | tr -d ' ')"
  say "conflicts $nconf kept copy(ies)$([ "$nconf" -gt 0 ] && printf ' under %s (cloud.sh conflicts)' "$CLOUD/conflicts")"
  load_adapter "$(cfg adapter)"
  say ""
  if adapter_check; then say "access    ok"; else say "access    FAILED"; return 1; fi
  say ""
  do_sync dry
}

cmd_conflicts() {
  local f rel any=0
  while IFS= read -r f; do
    any=1; rel="${f#"$CLOUD"/conflicts/}"; rel="${rel#*/}"; rel="${rel%.local}"; rel="${rel%.remote}"
    say "$f"
    say "    compare with $STORE/$rel; fold in what is missing, then delete this copy"
  done < <(find "$CLOUD/conflicts" -type f 2>/dev/null | sort)
  [ "$any" = 1 ] || say "no conflict copies"
}

case "${1:-}" in
  setup)     shift; cmd_setup "$@" ;;
  sync)      shift; cmd_sync "$@" ;;
  status)    shift; cmd_status "$@" ;;
  conflicts) shift; cmd_conflicts ;;
  off)       mkdir -p "$CLOUD"; touch "$CLOUD/off"; say "paused — background syncs skip until 'cloud.sh on'" ;;
  on)        rm -f "$CLOUD/off"; say "resumed" ;;
  -h|--help|'') sed -n '2,/^set -uo/p' "${BASH_SOURCE[0]}" | sed '$d; s/^# \{0,1\}//' >&2; exit 2 ;;
  *) die "unknown command: $1 (setup|sync|status|conflicts|off|on)" ;;
esac
