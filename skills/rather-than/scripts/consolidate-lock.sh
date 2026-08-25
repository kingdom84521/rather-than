#!/usr/bin/env bash
# Consolidation lock. mkdir is atomic on POSIX filesystems.
# Usage: consolidate-lock.sh acquire|release <root>
# Exit 0 on success; acquire exits 1 if the lock is held and fresh.
set -euo pipefail

op="${1:?usage: consolidate-lock.sh acquire|release <state-dir>}"
statedir="${2:?usage: consolidate-lock.sh acquire|release <state-dir>}"
lock="$statedir/consolidate.lock"
stale_minutes=10

mkdir -p "$statedir"

case "$op" in
  acquire)
    if mkdir "$lock" 2>/dev/null; then
      date +%s > "$lock/acquired"
      exit 0
    fi
    # Lock exists — steal only if stale.
    if [ -n "$(find "$lock" -maxdepth 0 -mmin +"$stale_minutes" 2>/dev/null)" ]; then
      rm -rf "$lock"
      if mkdir "$lock" 2>/dev/null; then
        date +%s > "$lock/acquired"
        exit 0
      fi
    fi
    echo "lock held: $lock" >&2
    exit 1
    ;;
  release)
    rm -rf "$lock"
    ;;
  *)
    echo "unknown op: $op" >&2
    exit 2
    ;;
esac
