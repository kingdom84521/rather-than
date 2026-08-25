#!/usr/bin/env bash
# Hygiene scorer for rather-than entries. 0-100, higher = more likely
# needs cleaning. Deterministic file math only — no LLM judgment.
# Dormancy uses ACT-R base-level activation B = ln(sum t_j^-d), d=0.5,
# over usage.log events. Results cached in <statedir>/hygiene.tsv keyed
# by an input fingerprint; unchanged entries are not recomputed.
# Usage: hygiene-score.sh <root> <statedir>
# Output (stdout + cache): slug<TAB>score<TAB>breakdown<TAB>fingerprint
set -euo pipefail

root="${1:?usage: hygiene-score.sh <root> <statedir>}"
statedir="${2:?usage: hygiene-score.sh <root> <statedir>}"
prefer="$root/prefer"
usage="$statedir/usage.log"
cache="$statedir/hygiene.tsv"
now="$(date +%s)"

mkdir -p "$statedir"
[ -d "$prefer" ] || { echo "no prefer/ under $root" >&2; exit 0; }
touch "$cache"

tmp="$cache.tmp.$$"
: > "$tmp"

for f in "$prefer"/*.md; do
  [ -e "$f" ] || continue
  slug="$(basename "$f" .md)"
  events="$(grep "^[0-9-]* $slug " "$usage" 2>/dev/null || true)"
  fp="$( (cat "$f"; printf '%s' "$events") | sha256sum | cut -c1-16 )"

  cached="$(awk -F'\t' -v s="$slug" -v fp="$fp" '$1==s && $4==fp' "$cache" | head -1)"
  if [ -n "$cached" ]; then
    printf '%s\n' "$cached" >> "$tmp"
    continue
  fi

  score_line="$(awk -v now="$now" -v slug="$slug" -v events="$events" '
    function ceilmin(x, m) { return x < m ? m : x }
    BEGIN {
      # ---- parse events: "YYYY-MM-DD slug verb ..." lines joined by \n
      n = split(events, ev, "\n"); na = 0; no = 0; nev = 0; act_sum = 0
      for (i = 1; i <= n; i++) {
        if (ev[i] == "") continue
        split(ev[i], p, " ")
        split(p[1], d, "-")
        ts = mktime(d[1] " " d[2] " " d[3] " 12 0 0")
        if (ts <= 0) continue
        days = ceilmin((now - ts) / 86400, 1)
        act_sum += days ^ -0.5
        nev++
        if (p[3] == "applied") na++
        if (p[3] == "overridden") no++
      }
    }
    END { printf "%d %d %d %f", nev, na, no, (act_sum > 0 ? log(act_sum) : -99) }
  ' </dev/null)"
  read -r nev na no bla <<< "$score_line"

  # frontmatter + body facts
  created="$(awk '/^created:[[:space:]]*/{sub(/^created:[[:space:]]*/,""); print; exit}' "$f")"
  category="$(awk '/^category:[[:space:]]*/{sub(/^category:[[:space:]]*/,""); print; exit}' "$f")"
  obs="$(awk '/^observed-in:[[:space:]]*/{sub(/^observed-in:[[:space:]]*/,""); print; exit}' "$f")"
  conf="$(awk '/^confidence:[[:space:]]*/{sub(/^confidence:[[:space:]]*/,""); print; exit}' "$f")"
  topic="$(awk '/^topic:[[:space:]]*/{sub(/^topic:[[:space:]]*/,""); print; exit}' "$f")"
  excepts="$(awk '/^## Except/{flag=1; next} /^## /{flag=0} flag && /^- /{n++} END{print n+0}' "$f")"
  evid="$(awk '/^## Evidence/{flag=1; next} /^## /{flag=0} flag && /^- /{n++} END{print n+0}' "$f")"

  age_days=0
  if [ -n "$created" ]; then
    cts="$(date -d "$created" +%s 2>/dev/null || echo "$now")"
    age_days=$(( (now - cts) / 86400 ))
  fi

  # ---- components
  dorm=0
  if [ "$nev" -eq 0 ]; then
    if [ "$age_days" -gt 30 ]; then dorm=35; else dorm=15; fi
  else
    # BLA >= 0 -> 0 pts; BLA <= -3 -> 35 pts; linear between
    dorm="$(awk -v b="$bla" 'BEGIN{ if (b >= 0) print 0; else if (b <= -3) print 35; else printf "%d", (-b/3)*35 }')"
  fi

  ovr=0
  if [ $((na + no)) -ge 3 ]; then
    ovr="$(awk -v a="$na" -v o="$no" 'BEGIN{ printf "%d", (o/(a+o))*20 }')"
  fi

  struct=0; struct_r=""
  [ -z "$category" ] && struct=$((struct+8)) && struct_r="${struct_r}no-category,"
  { [ -z "$obs" ] || [ "$obs" = "[]" ]; } && struct=$((struct+6)) && struct_r="${struct_r}no-observed-in,"
  [ "$conf" = "inferred" ] && struct=$((struct+6)) && struct_r="${struct_r}inferred,"
  case "$topic" in *,*) : ;; *) struct=$((struct+5)); struct_r="${struct_r}no-qualifier,";; esac

  exb=0
  [ "$excepts" -ge 3 ] && exb=15
  [ "$excepts" -eq 2 ] && exb=8

  thin=0
  [ "$evid" -le 1 ] && thin=5

  total=$((dorm + ovr + struct + exb + thin))
  breakdown="dorm:$dorm,ovr:$ovr,struct:$struct(${struct_r%%,}),except:$exb,thin:$thin,events:$nev"
  printf '%s\t%s\t%s\t%s\n' "$slug" "$total" "$breakdown" "$fp" >> "$tmp"
done

mv "$tmp" "$cache"
cat "$cache"
