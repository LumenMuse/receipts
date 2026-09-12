#!/bin/sh
# verify-commit.sh — check that objects/<hash>.commit really is the git commit object named by <hash>.
# A git object id is sha1("commit <bytes>\0" + body). No git, no repository needed: only sha1sum.
#   ./verify-commit.sh 2026-09-12.txt      → checks the object for that day's hash
#   ./verify-commit.sh <40-hex>            → checks that object directly
set -eu
arg="$1"
case "$arg" in *.txt) h=$(cut -c1-40 "$arg");; *) h="$arg";; esac
f="objects/$h.commit"
[ -f "$f" ] || { echo "MISSING: $f"; exit 2; }
got=$( (printf 'commit %s\0' "$(wc -c < "$f")"; cat "$f") | sha1sum | cut -c1-40)
if [ "$got" = "$h" ]; then
  echo "PASS: $f hashes to $h"
  echo "  parent: $(grep -m1 '^parent ' "$f" | cut -d' ' -f2)"
  echo "  committer epoch: $(grep -m1 '^committer ' "$f" | awk '{print $(NF-1)}')  ($(date -u -d @"$(grep -m1 '^committer ' "$f" | awk '{print $(NF-1)}')" +%Y-%m-%dT%H:%M:%SZ))"
  exit 0
else
  echo "FAIL: $f hashes to $got, not $h"; exit 1
fi
