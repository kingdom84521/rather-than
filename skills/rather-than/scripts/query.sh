#!/usr/bin/env bash
# Field-projected reads over a root's prefer/ entries. Consulting an entry no
# longer means cat'ing the whole file: the default projection returns what the
# apply path needs — topic, observed-in, Except — in a few lines per entry.
#
# Every printed entry logs a `consulted` usage event mechanically (the script
# ran, so the retrieval happened — no model discretion involved); activation
# counts retrievals, so consulting a cold entry is how it starts earning its
# way back. Pass -n for maintenance reads (Mode C view/review, audits) that
# must not count as use.
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
usage: query.sh <root> [-c <category>] [-s <slug>]... [-m <text>] [-f <fields>] [-n]
  -c  only entries in this category (exact match)
  -s  only this slug; repeatable
  -m  only entries whose topic, category, or observed-in contains <text>
      (case-insensitive substring)
  -f  comma-separated fields to print per entry, from:
      topic scope confidence category observed-in created reason except evidence
      default: topic,observed-in,except. 'all' prints every field and section.
  -n  do not log consulted events (maintenance reads, not use)
EOF
  exit 2
}

[ $# -ge 1 ] || usage
root="$1"; shift
prefer="$root/prefer"

category="" match_text="" fields="topic,observed-in,except" no_log=0
slugs=()
while getopts ':c:s:m:f:nh' opt; do
  case "$opt" in
    c) category="$OPTARG" ;;
    s) slugs+=("$OPTARG") ;;
    m) match_text="$OPTARG" ;;
    f) fields="$OPTARG" ;;
    n) no_log=1 ;;
    *) usage ;;
  esac
done

[ -d "$prefer" ] || exit 0

canon() { (cd "$1" 2>/dev/null && pwd -P) || printf '%s' "$1"; }

rt_store() {
  if [ -n "${RATHER_THAN_HOME:-}" ]; then printf '%s' "$RATHER_THAN_HOME"
  elif [ -d "$HOME/.claude/rather-than" ]; then printf '%s' "$HOME/.claude/rather-than"
  else printf '%s' "${XDG_DATA_HOME:-$HOME/.local/share}/rather-than"; fi
}

# Best-effort mirror of the hooks' state-dir layout; a derivation miss only
# loses a consulted line, never the read itself.
state_dir_for_root() {
  local r store key repo
  r="$(canon "$root")"
  store="$(canon "$(rt_store)")"
  case "$r" in
    "$store") printf '%s' "$store/.state/personal" ;;
    "$store"/team/*)
      key="${r#"$store"/team/}"; key="${key%%/*}"
      printf '%s' "$store/.state/team-$key" ;;
    */.claude/rather-than | */.rather-than)
      repo="${r%/.claude/rather-than}"; repo="${repo%/.rather-than}"
      key="$(basename "$repo")-$(printf '%s' "$repo" | sha256sum | cut -c1-8)"
      printf '%s' "$store/.state/project-$key" ;;
    *) printf '' ;;
  esac
}

sdir=""
[ "$no_log" = 1 ] || sdir="$(state_dir_for_root)"
today="$(date +%Y-%m-%d)"

want_slug() {
  [ "${#slugs[@]}" -eq 0 ] && return 0
  local s
  for s in "${slugs[@]}"; do [ "$s" = "$1" ] && return 0; done
  return 1
}

for f in "$prefer"/*.md; do
  [ -e "$f" ] || continue
  slug="$(basename "$f" .md)"
  want_slug "$slug" || continue
  if awk -v slug="$slug" -v fields="$fields" -v category="$category" -v needle="$match_text" '
    BEGIN {
      n = split(fields, F, ",")
      for (i = 1; i <= n; i++) want[F[i]] = 1
      all = ("all" in want)
    }
    NR == 1 && $0 == "---" { fm = 1; next }
    fm && $0 == "---" { fm = 0; next }
    fm {
      i = index($0, ":")
      if (i > 1) {
        key = substr($0, 1, i - 1)
        val = substr($0, i + 1)
        sub(/^[[:space:]]+/, "", val)
        meta[key] = val
        if (all || key in want) order[++m] = key
      }
      next
    }
    /^## / { sec = tolower(substr($0, 4)); next }
    sec != "" && (all || sec in want) && NF { body[sec] = body[sec] "\n  " $0 }
    END {
      if (category != "" && meta["category"] != category) exit 3
      if (needle != "") {
        hay = tolower(meta["topic"] " " meta["category"] " " meta["observed-in"])
        if (index(hay, tolower(needle)) == 0) exit 3
      }
      print slug
      for (i = 1; i <= m; i++) print "  " order[i] ": " meta[order[i]]
      split("reason except evidence", S, " ")
      for (i = 1; i <= 3; i++) if (S[i] in body) print "  " S[i] ":" body[S[i]]
    }
  ' "$f"; then
    if [ -n "$sdir" ]; then
      mkdir -p "$sdir" 2>/dev/null && \
        printf '%s %s consulted\n' "$today" "$slug" >> "$sdir/usage.log" 2>/dev/null || true
    fi
  fi
done
