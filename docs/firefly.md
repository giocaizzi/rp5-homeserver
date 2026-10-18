# Firefly III: ledger model and automation

How the finance stack (`services/firefly`) keeps Firefly equal to the bank without manual work. Procedures live in [RUNBOOKS](./RUNBOOKS/); the stack itself in [services/firefly/README.md](../services/firefly/README.md).

## Data flow

| Source | Path into Firefly | Cadence |
|---|---|---|
| Bank accounts and wallets (every currency) | Bank-data provider → Data Importer auto-import (`firefly_importer_config`, one mapping per provider account) | 06:00 daily |
| Credit card | Not exposed by the provider. Statement debit arrives with the current account; card rows come from file exports via [`scripts/firefly_cc_import.sh`](../scripts/firefly_cc_import.sh) | Monthly, optional |
| Checks and residuals | `firefly_jobs.py daily` in the scheduler | 07:00 daily |

Every provider account stays mapped, used or not: an empty wallet costs nothing and a later first transaction lands without config changes.

## Balances: booked only

Firefly holds **booked** transactions (the importer skips pending ones). Set the provider to report **booked** balances, so Firefly's current balance must equal the provider's balance to the cent. An *available* balance subtracts pending card authorizations and drifts from Firefly until they book. Opening balances are real bank figures at the first imported day; nothing else (no virtual balance, no plug transactions) absorbs differences.

## Credit card

The card is an asset account:

- statement debit → transfer settlement account → card (rule on the statement text);
- top-ups paid with the card → transfer card → the receiving asset (rule on the top-up token);
- itemized purchases → withdrawals from the card, `book_date` = statement registration date, external id `cc:<hash>`;
- anything a statement covers that is not itemized → one residual withdrawal per cycle to the residual expense account, tag `cc-residual`.

`firefly_jobs.py` recomputes the residual of the last four cycles every day (and after each card import): residual = statement − itemized purchases − card-funded top-ups + refunds, cycle membership by `book_date`. Importing a card file later shrinks or deletes the residual; skipping a month leaves one residual line. After each statement the card balance equals the open cycle's itemized spending (0 when nothing is itemized).

Caveat: top-ups booked from the receiving account carry that account's date, not the card registration date; one on a cycle boundary shows up as a residual on one cycle and an "itemized exceeds the statement" alert on the other.

## Daily checks (ntfy topic `firefly`)

| Check | Alert when |
|---|---|
| Card residuals | itemized spending exceeds a statement |
| Balance | provider balance ≠ Firefly current balance for any mapped account |
| Connection | provider account not `ACTIVE` (bank consent expired) or no longer listed |
| Import lag | provider has transactions more than a day newer than Firefly's latest |
| API token | `firefly_access_token` expires within 30 days |
| Review (Mondays) | transactions carry a tag listed in the stack env `FIREFLY_REVIEW_TAGS` |

What Firefly never shows: pending payments, card spending not yet exported, and the exact payment date of debit-card purchases (the bank books them 1–3 days later).

## Rules that keep the ledger consistent

- Rules fire on import (`store-journal`). Rules that **delete** (duplicate suppression) must never be applied by hand to history: they would delete the only remaining copy.
- Currency exchanges arrive as two unrelated legs (one per currency account) and are tagged for review; link them by hand into one transfer with a foreign amount.
- The API addresses transactions by **group** id, which can differ from the journal id.
