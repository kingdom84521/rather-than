#!/usr/bin/env bash
# 002 — add a Spans line to candidate blocks written before span discipline
# Since e3d3ec2 (2026-09-09). Sourced by scripts/init.sh; contract in README.md.
#
# e3d3ec2 made every `## candidate /` block carry `- Spans:` — for each
# load-bearing part of the topic (chosen side, instead-of side, scope), the
# verbatim receipt that backs it, or `inferred` when none does. A block
# written earlier has no such line, so A3 cannot tell what was quoted from
# what was guessed. The mechanical part is to mark all three parts
# `inferred`, which is exactly what they are: nothing recorded which
# receipt backed which part.
#
# What this cannot do — the semantic remainder — is recover the real
# spans. That is not lost work: `inferred` parts are confirmed by the A3
# question rather than asserted, so the user restores them when the
# candidate is asked. No separate step is needed.

MIG_SINCE=e3d3ec2
MIG_DATE=2026-09-09
MIG_TITLE="add a Spans line to candidate blocks written before span discipline"

m002_spans='- Spans: chosen=inferred · instead-of=inferred · scope=inferred'

m002_count() { # <journal> → number of candidate blocks lacking Spans
  awk '
    /^## candidate \/ / { if (inb && !has) n++; inb = 1; has = 0; next }
    /^## /              { if (inb && !has) n++; inb = 0; next }
    inb && /^- Spans:/  { has = 1 }
    END                 { if (inb && !has) n++; print n + 0 }' "$1"
}

m002_fix() { # <journal>, in place; Spans goes after Strength, or right after
             # the heading when a block has no Strength line
  local f="$1" tmp="$1.tmp.$$"
  awk -v spans="$m002_spans" '
    FNR == NR {
      if ($0 ~ /^## candidate \/ /) { b++; inb = 1; next }
      if ($0 ~ /^## /)              { inb = 0; next }
      if (inb && $0 ~ /^- Spans:/)    has[b] = 1
      if (inb && $0 ~ /^- Strength:/) str[b] = 1
      next
    }
    /^## candidate \/ / { cur = ++k; print; if (!has[cur] && !str[cur]) print spans; next }
    /^## /              { cur = 0; print; next }
    cur && !has[cur] && /^- Strength:/ { print; print spans; next }
    { print }' "$f" "$f" > "$tmp" && mv "$tmp" "$f"
}

m002_each() { # <plan|apply>
  local f n
  for f in "$STORE"/journal/*.md; do
    [ -f "$f" ] || continue
    n="$(m002_count "$f")"
    [ "${n:-0}" -gt 0 ] || continue
    say "$n candidate block(s) in journal/$(basename "$f")"
    [ "$1" = apply ] && m002_fix "$f"
  done
  return 0
}

mig_plan()  { m002_each plan; }
mig_apply() { m002_each apply; }
