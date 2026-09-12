#!/usr/bin/env bash
# Regenerate LEDGER.md from the disk: one row per receipt, block heights read
# out of the .ots proof itself (`ots info`), never typed. Run from receipts/.
set -euo pipefail
cd "$(dirname "$0")"
OTS="${OTS:-ots}"
{
  echo "# receipts ledger — generated $(date -u +%Y-%m-%dT%H:%M:%SZ) by ledger.sh; do not edit by hand"
  echo
  echo "| day | date | memory HEAD | bitcoin block(s) | status |"
  echo "|---|---|---|---|---|"
  echo "| 1 | 2026-09-02 | 2b24446 | — | plain post at://did:plc:a3nr3jzwxvmwgmbx7rhptcms/app.bsky.feed.post/3mukmnqz26h2y (no .ots) |"
  n=1
  for t in $(ls *.txt | sort); do
    n=$((n+1)); d=${t%.txt}; h=$(cut -c1-7 "$t")
    if [ -f "$t.ots" ]; then
      blocks=$($OTS info "$t.ots" 2>/dev/null | grep -o 'BitcoinBlockHeaderAttestation([0-9]*)' | grep -o '[0-9]*' | sort -un | paste -sd, - || true)
      if [ -n "$blocks" ]; then st=anchored; else blocks="—"; st="pending (calendar)"; fi
    else blocks="—"; st="no proof file"; fi
    echo "| $n | $d | $h | $blocks | $st |"
  done
  echo
  echo "Anchored rows: $(ls *.txt.ots 2>/dev/null | while read f; do $OTS info "$f" 2>/dev/null | grep -q BitcoinBlockHeaderAttestation && echo x; done | wc -l) of $(ls *.txt | wc -l) proofs; day 1 is the plain post."
  echo
  echo "Each HEAD is an ancestor of the next (git carries the chain); the stamp is on the HEAD hash only. Verify any row: \`../verify-receipt.sh DATE.txt.ots\`."
} > LEDGER.md
