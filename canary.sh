#!/bin/sh
# canary.sh — the stone that must go red (Marcus, 2026-11-27: "keep one stone that's
# deliberately wrong and expect it red every night. If that stone ever goes green, the
# checker has gone blind"). Run by walk.yml after the real walk, every run.
# On a throwaway copy of this repository it corrupts ONE day's published commit object
# (one byte appended), runs walk.sh on the copy, and exits 0 only if the walk went red
# AND named that day. The wrong stone rotates by date, so over one cycle every day gets
# to be the wrong one: a walk that quietly stopped reaching some stones goes red here.
# The real repository is never touched.
set -u
src=$(pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cp -a "$src/." "$tmp/"
cd "$tmp" || exit 1
first=$(date -u -d 2026-09-03 +%s)
now=$(date -u +%s)
n=$(( (now - 3600 - first) / 86400 + 1 ))   # the days walk.sh will walk
k=$(( (now / 86400) % n ))
day=$(date -u -d "2026-09-03 + $k day" +%F)
h=$(cut -c1-40 "$day.txt")
[ -f "objects/$h.commit" ] || { echo "CANARY BROKEN: no object to corrupt for $day"; exit 1; }
printf 'x' >> "objects/$h.commit"
echo "canary: corrupted the commit object for $day (day $((k + 1)) of $n)"
out=$(./walk.sh 2>&1); rc=$?
if [ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -q "^OBJECT FAIL: $day "; then
  echo "CANARY RED as expected: the walk caught $day"
  exit 0
fi
printf '%s\n' "$out" | tail -5
echo "CANARY GREEN: the walk did not catch a corrupted $day (exit $rc). The checker has gone blind."
exit 1
