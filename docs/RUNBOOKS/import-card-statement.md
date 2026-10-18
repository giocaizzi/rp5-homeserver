# Import a credit-card statement

**When:** card rows are available from a bank export and you want the card spending itemized instead of one residual line. Optional; skipping it never breaks balances.
**Preconditions:** SSH to the Pi, the scheduler running the current stack release, and a parser (kept outside this repo, it is bank-specific) that turns the export into JSON rows.

## Steps
1. Convert the export to a JSON array of booked card rows, amount signed (purchase < 0):
   ```json
   [{"date": "2026-09-14", "booked": "2026-09-16", "amount": -12.50, "description": "MERCHANT CITY"}]
   ```
   `date` is the operation date, `booked` the statement registration date (it decides the cycle).
2. Pipe it to the scheduler:
   ```bash
   ssh pi@pi.local 'docker exec -i "$(docker ps -qf label=com.docker.swarm.service.name=firefly_scheduler | head -1)" python3 /usr/local/bin/firefly_jobs.py cc-import' < rows.json
   ```
   Rows starting with a prefix in `FIREFLY_CC_SKIP_PREFIXES` are skipped, and so are rows already in Firefly (same external id, or same date and amount).

## Verify
The output ends with `card import: N posted, M skipped` and one `card cycle to <date> … residual X -> 0.00` line per cycle now fully itemized. No `ALERT` lines. Piping the same file again posts 0.

## Rollback
Delete the imported rows (tag `cc-itemized`, the file's dates) in Firefly, then run `docker exec <scheduler> python3 /usr/local/bin/firefly_jobs.py daily` to restore the residuals.

**Last verified:** 2026-10-18 by Claude Code (cc-import and cycle recompute on the Pi)
