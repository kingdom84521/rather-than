#!/usr/bin/env bash
# Field-projected reads over a root's prefer/ entries. Consulting an entry no
# longer means cat'ing the whole file: the default projection returns what the
# apply path needs — topic, observed-in, Except — in a few lines per entry.
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
usage: query.sh <root> [-c <category>] [-s <slug>]... [-m <text>] [-f <fields>]
  -c  only entries in this category (exact match)
  -s  only this slug; repeatable
  -m  only entries whose topic, category, or observed-in contains <text>
      (case-insensitive substring)
  -f  comma-separated fields to print per entry, from:
      topic scope confidence category observed-in created reason except evidence
      default: topic,observed-in,except. 'all' prints every field and section.
EOF
  exit 2
}

[ $# -ge 1 ] || usage
root="$1"; shift
prefer="$root/prefer"

category="" match_text="" fields="topic,observed-in,except"
slugs=()
while getopts ':c:s:m:f:h' opt; do
  case "$opt" in
    c) category="$OPTARG" ;;
    s) slugs+=("$OPTARG") ;;
    m) match_text="$OPTARG" ;;
    f) fields="$OPTARG" ;;
    *) usage ;;
  esac
done

[ -d "$prefer" ] || exit 0

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
  awk -v slug="$slug" -v fields="$fields" -v category="$category" -v needle="$match_text" '
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
      if (category != "" && meta["category"] != category) exit 0
      if (needle != "") {
        hay = tolower(meta["topic"] " " meta["category"] " " meta["observed-in"])
        if (index(hay, tolower(needle)) == 0) exit 0
      }
      print slug
      for (i = 1; i <= m; i++) print "  " order[i] ": " meta[order[i]]
      split("reason except evidence", S, " ")
      for (i = 1; i <= 3; i++) if (S[i] in body) print "  " S[i] ":" body[S[i]]
    }
  ' "$f"
done
