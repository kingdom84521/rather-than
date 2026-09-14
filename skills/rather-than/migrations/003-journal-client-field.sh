#!/usr/bin/env bash
# 003 — add the client field to journal provenance headers written before it
# Since d05757b (2026-09-09). Sourced by scripts/init.sh; contract in README.md.
#
# d05757b gave the provenance header a `client` field (which harness ran the
# session) so capture eagerness can be counted per client. A header from
# before then has no such field. The value written here is `unrecorded` —
# deliberately not `unknown`, which is what the hook writes when it runs
# and cannot tell; `unrecorded` means the session predates the field.
#
# What this cannot do — the semantic remainder — is repair what the same
# commit changed about the raw lines: before d05757b nothing required the
# subject "User" to be the human, or one event to take one line. A journal
# whose header reads `client unrecorded` was written under the old rules,
# and DETECTION.md's legacy-journal rule tells analysis how to read it.
# That rule is permanent and keyed on the header, so no one-time step is
# recorded here.

MIG_SINCE=d05757b
MIG_DATE=2026-09-09
MIG_TITLE="add the client field to journal provenance headers written before it existed"

m003_needs() { # <journal> → true when line 1 is an old-shape header
  local first
  first="$(head -n 1 "$1")"
  case "$first" in
    '<!-- session '*' | team-staging-root '*' | started '*' -->')
      case "$first" in *' | client '*) return 1 ;; *) return 0 ;; esac ;;
    *) return 1 ;;
  esac
}

m003_each() { # <plan|apply>
  local f tmp
  for f in "$STORE"/journal/*.md; do
    [ -f "$f" ] || continue
    m003_needs "$f" || continue
    say "header of journal/$(basename "$f")"
    if [ "$1" = apply ]; then
      tmp="$f.tmp.$$"
      { head -n 1 "$f" | sed 's/ | started / | client unrecorded | started /'; tail -n +2 "$f"; } > "$tmp" && mv "$tmp" "$f"
    fi
  done
  return 0
}

mig_plan()  { m003_each plan; }
mig_apply() { m003_each apply; }
