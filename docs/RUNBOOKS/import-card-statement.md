# Import a credit-card statement

**When:** a card statement or a current-account movements export is available and you want the card spending itemized instead of one residual line. Optional; skipping it never breaks balances.
**Preconditions:** SSH to the Pi, `uv` on the Mac, the scheduler running the current stack release.

## Steps
1. Download the card's monthly statement (`.xls`) or the current-account movements export (`.xlsx`, it also lists card rows).
2. Run, with one or more files:
   ```bash
   PI_SSH_USER=pi ./scripts/firefly_cc_import.sh ~/Downloads/statement.xls
   # movements export: also set CC_ROW_PREFIX=<Descrizione prefix of card rows>
   ```
   Card rows go to the scheduler; rows starting with a prefix in the stack env `FIREFLY_CC_SKIP_PREFIXES` (card-funded top-ups, already booked from the receiving account) are skipped; rows already in Firefly (same external id, or same date and amount) are skipped.

## Verify
The output ends with `card import: N posted, M skipped` and one `card cycle to <date> … residual X -> 0.00` line per cycle now fully itemized. No `ALERT` lines. Running the same file again posts 0.

## Rollback
Delete the imported rows (tag `cc-itemized`, the file's dates) in Firefly, then run `docker exec <scheduler> python3 /usr/local/bin/firefly_jobs.py daily` to restore the residuals.

**Last verified:** 2026-10-18 by Claude Code (converter on both formats; cycle recompute on the Pi)
