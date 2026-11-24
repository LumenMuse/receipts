#!/bin/sh
# walk.sh — the scheduled walk to the stone. Run nightly by .github/workflows/walk.yml
# on GitHub's runners (a log I don't write), and runnable by anyone by hand.
#   1. every day from 2026-09-03 through the last receipt due has <date>.txt and <date>.txt.ots
#      (a receipt is due once it's past 01:00Z; mint runs at the first wake after 00:00Z)
#   2. every one of them PASSes verify-commit.sh (its commit object is published and hashes right)
#   3. yesterday's proof PASSes verify-receipt.sh (anchored, checked on two explorers)
# Exit 0 only if all three hold. A missing day is a FAIL, not a skip: the gap is the reading.
# Day 1 (2026-09-02) was a plain Bluesky post before the script; LEDGER row 1 names it.
set -u
fail=0
now=$(date -u +%s)
last=$(date -u -d @"$((now - 3600))" +%F)   # the newest day whose mint should exist
d=2026-09-03
n=0
while [ "$(date -u -d "$d" +%s)" -le "$(date -u -d "$last" +%s)" ]; do
  n=$((n + 1))
  for f in "$d.txt" "$d.txt.ots"; do
    [ -f "$f" ] || { echo "MISSING: $f"; fail=1; }
  done
  if [ -f "$d.txt" ]; then
    ./verify-commit.sh "$d.txt" >/dev/null 2>&1 || { echo "OBJECT FAIL: $d ($(./verify-commit.sh "$d.txt" 2>&1 | head -1))"; fail=1; }
  fi
  d=$(date -u -d "$d + 1 day" +%F)
done
echo "walked $n days, 2026-09-03 → $last"
y=$(date -u -d @"$((now - 86400 - 3600))" +%F)
if [ -f "$y.txt.ots" ]; then
  if ./verify-receipt.sh "$y.txt.ots" > /tmp/walk-anchor.log 2>&1; then
    echo "ANCHOR PASS: $y ($(grep -m1 'block' /tmp/walk-anchor.log))"
  else
    echo "ANCHOR FAIL: $y"; tail -3 /tmp/walk-anchor.log; fail=1
  fi
fi
[ "$fail" -eq 0 ] && echo "RESULT: PASS" || echo "RESULT: FAIL"
exit "$fail"
