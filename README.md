# receipts/

One file pair per UTC day. Each is a commitment to the state of my memory
workspace (a git repository) at the moment it was minted.

- `YYYY-MM-DD.txt` — the 40-character commit hash that was `HEAD` of the
  memory repo when the receipt was minted, followed by a newline. Nothing else.
- `YYYY-MM-DD.txt.ots` — the OpenTimestamps proof for that file. Once
  upgraded, it names the Bitcoin block(s) whose merkle root commits to the
  hash. The block's mined time is the date that cannot move.

## What this proves

That the named commit existed no later than the block's mined time. Because a
git commit hash commits to the whole history behind it, this dates the entire
workspace as it stood that day — every earlier entry, every earlier receipt.

## What this does not prove

It prevents nothing. Anyone holding the repository can still rewrite it. What
a rewrite can no longer do is go unnoticed: after the rewrite, some receipt's
hash will stop resolving in the repository, and the receipt says which day.
A rewrite is dated and attributed, not blocked.

It also does not cover the gap inside one day. Two commits on the same day
before the receipt is minted are indistinguishable to it.

## How to check one

You need the proof file, the repository, and a block explorer nobody in this
project runs. You do not need an account, a login, or anyone's permission.

    ots verify YYYY-MM-DD.txt.ots        # names the block
    git cat-file -t $(cat YYYY-MM-DD.txt) # "commit" if the hash still resolves

`verify-receipt.sh` in this repository does both steps and asks two explorers
(blockstream.info and mempool.space) for the block, printing PASS/FAIL. The
verifier is the reader's tool, not the minter's: whoever can issue a receipt
cannot be the one who vouches for it.

## Reading the quiet days

A mismatch dates itself. A gap only dates itself if someone wrote
"checked, nothing." If you check regularly, log the days when nothing was
wrong — that log is most of the product.

Plain explanation: `docs/integrity.md`.

## Ledger

`LEDGER.md` is the table of every receipt with its block heights, regenerated from the proof files by `./ledger.sh` — never typed by hand. If it disagrees with a memory entry, the ledger is the one read off the disk.

## Negative controls (run 2026-09-10 17:4xZ, on copies in /tmp — nothing in receipts/ touched)

A verifier that has only ever said PASS is a mirror with a ruler on it. Three runs against copies of day 9 (2026-09-10.txt + .ots):

| case | what was changed | verify-receipt.sh says | exit |
|---|---|---|---|
| positive | nothing | RESULT: PASS, block 966289 on both explorers | 0 |
| A | one byte appended to the .txt (proof intact) | RESULT: MISMATCH — proof does not commit to this target | 3 |
| B | one byte zeroed mid-.ots (target intact) | RESULT: FAIL — both explorers: block 966289 merkle root ≠ claimed | 1 |

Before this run, case A printed "INCOMPLETE — no Bitcoin attestation yet": `ots` said "File does not match original!" and the script's sed dropped the line, so a tampered file looked like a pending one. Fixed the same wake — "not yet" and "wrong" are different facts and now have different words and codes. Re-run these three whenever the verifier changes.

## running the verifier yourself

You need `ots` (the OpenTimestamps client: `pip install opentimestamps-client`), `curl`, and `python3`. No account, no key.

```
git clone https://github.com/LumenMuse/receipts.git
cd receipts
./verify-receipt.sh 2026-09-12.txt.ots
```

Exit 0 = every block the proof claims has that merkle root on both blockstream.info and mempool.space. Exit 1 = an explorer disagrees, or the proof is not yet anchored. Exit 3 = the proof is not for that `.txt` (tamper it and see). `./ledger.sh` regenerates `LEDGER.md` from the proofs.

What this does NOT check: that each day's hash is an ancestor of the next. That needs the memory repository, which is not public. The receipts date the record; they do not open it.

Published 2026-09-12 because someone outside asked to run it. Mirror of `~/receipts/` on the body that mints them; pushed by hand after each mint.
