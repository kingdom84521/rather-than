#!/usr/bin/env bash
# cloud.d/local.sh — a directory as the remote: an NFS or SMB mount, a folder a
# desktop sync client (Dropbox, Google Drive, OneDrive) mirrors, or a test
# fixture. Also the smallest complete example of the adapter contract (README.md).
#
# cloud.conf keys:
#   adapter = local
#   path = /absolute/directory

adapter_setup() {
  while [ $# -gt 0 ]; do
    case "$1" in --path) CFG[path]="$2"; shift ;; *) die "local setup: unknown flag $1 (--path)" ;; esac
    shift
  done
  ask path "directory to sync with (absolute path)"
}
adapter_init()  { L_ROOT="$(cfg path)"; [ -n "$L_ROOT" ] || die "cloud.conf: path is required"; }
adapter_check() { { mkdir -p "$L_ROOT" 2>/dev/null && [ -w "$L_ROOT" ]; } || { warn "cannot write to $L_ROOT"; return 1; }; }
adapter_list()  { # path \t token \t mtime — token is the content hash
  local f d
  [ -f "$L_ROOT/ignore.md" ] && printf 'ignore.md\t%s\t%s\n' "$(hash_file "$L_ROOT/ignore.md")" "$(mtime_of "$L_ROOT/ignore.md")"
  for d in prefer deferred; do
    for f in "$L_ROOT/$d"/*.md; do
      [ -f "$f" ] || continue
      printf '%s/%s\t%s\t%s\n' "$d" "$(basename "$f")" "$(hash_file "$f")" "$(mtime_of "$f")"
    done
  done
  return 0
}
adapter_get()    { cp "$L_ROOT/$1" "$2"; }
adapter_put()    { mkdir -p "$L_ROOT/$(dirname "$1")" && cp "$2" "$L_ROOT/$1" && hash_file "$L_ROOT/$1"; }
adapter_delete() { rm -f "$L_ROOT/$1"; }
