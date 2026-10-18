# Firefly III: ledger model and automation

How the finance stack (`services/firefly`) keeps Firefly equal to the bank without manual work. Procedures live in [RUNBOOKS](./RUNBOOKS/); the stack itself in [services/firefly/README.md](../services/firefly/README.md).

## Data flow

| Source | Path into Firefly | Cadence |
|---|---|---|
| Bank accounts and wallets | Bank-data provider → Data Importer auto-import (`firefly_importer_config`, one mapping per provider account) | 06:00 daily |
| Credit card | Not exposed by the provider. Statement debit arrives with the settlement account; card rows are optional, from file exports ([Import a credit-card statement](./RUNBOOKS/import-card-statement.md)) | When a statement is available |
| Checks and residuals | `firefly_jobs.py daily` in the scheduler | 07:00 daily |

## Balances: booked only

Firefly holds **booked** transactions (the importer skips pending ones), so the provider must report **booked** balances for the balance check to compare like with like. Opening balances are real bank figures; nothing else (virtual balance, plug transactions) absorbs differences.

## Credit card

The card is an asset account:

- statement debit → transfer settlement account → card;
- top-ups paid with the card → transfer card → the receiving asset;
- itemized purchases → withdrawals from the card, `book_date` = statement registration date, external id `cc:<hash>`;
- anything a statement covers that is not itemized → one residual withdrawal per cycle to the residual expense account, tag `cc-residual`.

`firefly_jobs.py` recomputes the residual of the last four cycles every day and after each card import: residual = statement − itemized purchases − card-funded top-ups + refunds, cycle membership by `book_date`. Importing a card file later shrinks or deletes the residual; skipping one leaves the residual line. After each statement the card balance equals the open cycle's itemized spending.

Caveat: a top-up booked from the receiving account carries that account's date; one on a cycle boundary shows up as a residual on one cycle and an "itemized exceeds the statement" alert on the other.

## Daily checks (ntfy topic `firefly`)

| Check | Alert when |
|---|---|
| Card residuals | itemized spending exceeds a statement |
| Balance | provider balance ≠ Firefly current balance for any mapped account |
| Connection | provider account not `ACTIVE` (bank consent expired) or no longer listed |
| Import lag | provider has transactions more than a day newer than Firefly's latest |
| API token | `firefly_access_token` expires within 30 days |
| Review (Mondays) | transactions carry a tag listed in `FIREFLY_REVIEW_TAGS` |

## MCP connectors

The MCP endpoint `/api/v1/mcp` serves two disjoint tool sets, chosen by the `toolset` query parameter. Each tool is in exactly one, so a client with both connectors sees every tool once:

- **everyday** (default, no parameter): 38 tools for reading, searching, totals, classification, imports, bills and rules (list/test/create/update). Use it as the always-on "Firefly" connector.
- **admin** (`?toolset=admin`): the other 25 tools: budgets, piggy banks, recurrences, currencies, attachments, links, object groups, webhooks, account/bill writes, rule groups, `apply-rule` and deletes of rules, accounts and categories. Add it as a second connector ("Firefly admin") and enable it only when needed.

Claude Code in `~/ops` has both (`firefly` and `firefly-admin` in `~/ops/.mcp.json`). Both go through the same Worker (`mcp-connector-firefly`), which passes the query string through; see [workers/mcp-connector](../workers/mcp-connector/README.md). Any other value returns HTTP 400, and calling a tool on the wrong set returns an error naming the right one.

## Stack env (Portainer)

| Variable | Required | Meaning |
|---|---|---|
| `CC_ACCOUNT_ID` | yes | Firefly id of the card asset account |
| `CC_SETTLEMENT_SOURCE_ID` | yes | Firefly id of the account the statement is debited from |
| `CC_RESIDUAL_ACCOUNT_ID` | yes | Firefly id of the expense account for unitemized card spending |
| `FIREFLY_CC_CLOSE_MARKER` | no | word before the close date (`dd/mm/yy`) in the statement debit text; unset = cycle closes at month end |
| `FIREFLY_CC_SKIP_PREFIXES` | no | `;`-separated description prefixes of card rows to skip on import (card-funded top-ups already booked) |
| `FIREFLY_REVIEW_TAGS` | no | `;`-separated tags listed every Monday |

Portainer's API replaces the whole env list on update: send every variable. Separate list values with `;`: Portainer cuts a swarm stack env value at the first comma when it deploys (`,` still works when the value reaches the container intact).
