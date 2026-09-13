#!/bin/sh
# verify-receipt.sh — reader-side check of one integrity receipt (issue #101).
#
# The keeper's machine mints the receipt; this script is what a READER runs.
# It never trusts the local toolchain's verdict about Bitcoin: `ots` only
# tells us which block and which merkle root the proof claims, and then we ask
# two explorers we don't operate whether that block really has that root.
#
#   1. ots --no-bitcoin verify <proof>   → "block N has merkleroot X" lines
#   2. for each (N, X): fetch block N from blockstream.info AND mempool.space
#   3. print PASS/FAIL per block per explorer, plus the block's timestamp
#      (the moment before which the receipt's hash provably existed)
#   4. exit 0 only if every claimed block matched on every explorer
#      exit 1 = FAIL (explorer disagrees) or INCOMPLETE (unanchored);
#      exit 2 = missing file; exit 3 = MISMATCH (proof is not for this target)
#      exit 4 = NOT A PROOF (argument is not an .ots file)
#
# Usage:   verify-receipt.sh receipts/<date>.txt.ots
# Env:     OTS (default below). Needs curl + jq.

set -eu

OTS="${OTS:-/home/lumen/bin/ots}"
proof="${1:?usage: verify-receipt.sh <file>.ots}"
target="${proof%.ots}"

[ -e "$proof" ]  || { echo "no such proof: $proof" >&2; exit 2; }

# The argument must BE a proof. Passed a bare .txt, the old script made the
# text file its own target and reported INCOMPLETE — a wrong-input error
# wearing an unanchored proof's face. (Negative control found by Aria's outside
# run, 2026-09-13: her runner passed 2026-09-12.txt.) Two checks: the name
# ends in .ots and is not its own target; the bytes start with the
# OpenTimestamps magic header.
if [ "$target" = "$proof" ]; then
  echo "RESULT: NOT A PROOF — $proof does not end in .ots (usage: verify-receipt.sh <file>.ots)" >&2
  exit 4
fi
magic="$(head -c 15 "$proof" | od -An -c | tr -d ' \n')"
case "$magic" in
  *OpenTimestamps*) ;;
  *) echo "RESULT: NOT A PROOF — $proof lacks the OpenTimestamps magic header" >&2; exit 4 ;;
esac

[ -e "$target" ] || { echo "no such target file: $target" >&2; exit 2; }

echo "target: $target"
echo "sha256: $(shasum -a 256 "$target" | cut -d' ' -f1)"
echo "claims: $(sed -n 1p "$target")"

raw="$("$OTS" --no-bitcoin verify "$proof" 2>&1 || true)"

# A proof that does not commit to THIS target is a different fact from a proof
# that is merely unanchored. Say which. (Negative control, 2026-09-10.)
if printf '%s\n' "$raw" | grep -q 'does not match'; then
  echo "RESULT: MISMATCH — proof does not commit to $target (target altered, or wrong proof for this file)"
  exit 3
fi

claims="$(printf '%s\n' "$raw" \
  | sed -n 's/.*Bitcoin block \([0-9]*\) has merkleroot \([0-9a-f]*\).*/\1 \2/p' \
  | sort -u)"

if [ -z "$claims" ]; then
  echo "RESULT: INCOMPLETE — proof carries no Bitcoin attestation yet (run: ots upgrade $proof)"
  exit 1
fi

fail=0
check() {
  # $1 explorer name, $2 api base, $3 height, $4 expected merkleroot
  hash="$(curl -sf "$2/block-height/$3")" || { echo "  $1: FAIL (could not resolve height $3)"; fail=1; return; }
  json="$(curl -sf "$2/block/$hash")"    || { echo "  $1: FAIL (could not fetch block $hash)"; fail=1; return; }
  got="$(printf '%s' "$json" | jq -r .merkle_root)"
  ts="$(printf '%s' "$json" | jq -r '.timestamp | todate')"
  if [ "$got" = "$4" ]; then
    echo "  $1: PASS — block $3 mined $ts, merkle root matches"
  else
    echo "  $1: FAIL — block $3 merkle root is $got, proof claims $4"
    fail=1
  fi
}

report="$(mktemp "${TMPDIR:-/tmp}/verify-receipt.XXXXXX")"
trap 'rm -f "$report"' EXIT

printf '%s\n' "$claims" | while read -r height root; do
  echo "attestation: Bitcoin block $height, merkle root $root"
  check blockstream https://blockstream.info/api "$height" "$root"
  check mempool.space https://mempool.space/api "$height" "$root"
done | tee "$report"

# `fail` was set inside a pipeline subshell; the report is the source of truth.
if grep -q 'FAIL' "$report"; then
  echo "RESULT: FAIL — see lines above"
  exit 1
fi
echo "RESULT: PASS — every claimed block matched on both explorers"
exit 0
