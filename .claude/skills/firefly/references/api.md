# Firefly III REST API reference

Operational reference for the API exposed by `firefly_app` on `/api/v1`. Read this whenever you need to drive Firefly programmatically.

Upstream: <https://api-docs.firefly-iii.org/>. Use this file first — it is tailored to *this* deployment and the typical workflows. Hit the upstream OpenAPI only when you need a field this file does not cover.

## Table of contents
- [1. Base, auth, content-type](#1-base-auth-content-type)
- [2. Pagination, sorting, dates](#2-pagination-sorting-dates)
- [3. Error model](#3-error-model)
- [4. About, summary, search, autocomplete](#4-about-summary-search-autocomplete)
- [5. Accounts](#5-accounts)
- [6. Transactions](#6-transactions)
- [7. Categories, tags, budgets, bills, piggy banks](#7-categories-tags-budgets-bills-piggy-banks)
- [8. Recurrences](#8-recurrences)
- [9. Rules and rule groups](#9-rules-and-rule-groups)
- [10. Webhooks](#10-webhooks)
- [11. Attachments, links, object-groups, preferences, configuration](#11-attachments-links-object-groups-preferences-configuration)
- [12. Currencies and exchange rates](#12-currencies-and-exchange-rates)
- [13. Charts, insight, reports](#13-charts-insight-reports)
- [14. Data export, destroy, purge, bulk update](#14-data-export-destroy-purge-bulk-update)
- [15. Users, user-groups, batch, system](#15-users-user-groups-batch-system)

---

## 1. Base, auth, content-type

- **Base URL inside the swarm:** `http://firefly-app:8080/api/v1`
- **Base URL from the public side:** `https://firefly.giocaizzi.xyz/api/v1`
- **Auth:** `Authorization: Bearer <personal_access_token>`. The token is the Swarm secret `firefly_access_token`, mounted in `firefly-scheduler` at `/run/secrets/firefly_access_token`. To generate a new one: Firefly UI → Profile → OAuth → Personal Access Tokens.
- **Required headers:** `Accept: application/vnd.api+json` (preferred) or `Accept: application/json` is accepted. `Content-Type: application/json` for `POST`/`PUT`.
- **Scopes:** Personal Access Tokens have all scopes. OAuth clients (e.g. the Data Importer) need the `*` scope on creation.

### Helper

Use `scripts/ff-api.sh` from this skill's root — it handles SSH + token loading + container exec. Verbatim curl from the host looks like:

```bash
ssh giorgiocaizzi@pi.local '
  SCHED=$(docker ps -qf "label=com.docker.swarm.service.name=firefly_scheduler" | head -1)
  TOKEN=$(docker exec $SCHED cat /run/secrets/firefly_access_token)
  APP=$(docker ps -qf "label=com.docker.swarm.service.name=firefly_app" | head -1)
  docker exec $APP curl -sS \
    -H "Accept: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    http://localhost:8080/api/v1/about
'
```

## 2. Pagination, sorting, dates

- **Pagination:** `?page=1&limit=50`. Default 50, max usually 100. Response shape:
  ```json
  {
    "data": [...],
    "meta": {
      "pagination": {"total": 1234, "count": 50, "per_page": 50, "current_page": 1, "total_pages": 25}
    },
    "links": {"self": "...", "first": "...", "next": "...", "last": "..."}
  }
  ```
- **Iterating:** loop while `meta.pagination.current_page < meta.pagination.total_pages`.
- **Date filters** on transactions/charts: `?start=YYYY-MM-DD&end=YYYY-MM-DD` (inclusive both ends).
- **Sorting** is generally not exposed via query — order is server-default (date desc for transactions). Do client-side sort if needed.
- **Single-resource fetch** ignores pagination.

## 3. Error model

| Status | Meaning |
|---|---|
| `200 OK` | Read success |
| `204 No Content` | Delete success |
| `401 Unauthenticated` | Missing/invalid bearer token, or OAuth keys missing |
| `403 Unauthorized` | Token has no rights to this resource (cross-user) |
| `404 Not Found` | Resource doesn't exist or is soft-deleted |
| `422 Unprocessable Entity` | Validation failure — body has `message` and `errors` map |
| `429 Too Many Requests` | Rare; mostly the cron endpoint and webhooks |
| `500` | Server error — check `php artisan firefly-iii:report-integrity` and app logs |

Validation responses look like:
```json
{
  "message": "The given data was invalid.",
  "errors": {
    "transactions.0.amount": ["The amount must be a string."],
    "transactions.0.source_id": ["The source id field is required when source name is not present."]
  }
}
```

Special application error codes appear in messages — most notable:
- **`a115`** = "duplicate transaction hash". Returned when an identical transaction (same date+amounts+accounts) already exists. Not a bug; mark the import as idempotent.

## 4. About, summary, search, autocomplete

### `GET /about`
System info — version, OS, PHP version, driver. Use as a health check (`firefly-app` healthcheck hits this).

### `GET /about/user`
Currently authenticated user (id, email, role).

### `GET /summary/basic?start=YYYY-MM-DD&end=YYYY-MM-DD&currency_code=EUR`
Dashboard cards: balance, net-worth, spent, earned, bills, all keyed by `<metric>-in-<CUR>` (e.g. `balance-in-EUR`). The fastest way to fetch the "top of dashboard" numbers.

### `GET /search/transactions?query=<q>&page=N`
Full-text + structured search. The query syntax mirrors the Firefly UI search bar: `amount:100`, `category:Groceries`, `tag:tax`, `account:"Main checking"`, `date:2026-01..2026-03`, `notes_contain:VISA`. Combine with spaces (AND).
- `GET /search/transactions/count?query=<q>` returns just the count.
- `GET /search/accounts?query=<q>&field=all` finds accounts by name/iban/number.

### Autocomplete (`/autocomplete/*`)
Lightweight name→id lookups for UI typeaheads, but very useful in scripts. All take `?query=<prefix>&limit=10`.
- `/autocomplete/accounts?types=Asset%20account,Expense%20account&query=ama`
- `/autocomplete/categories`, `/autocomplete/tags`, `/autocomplete/budgets`
- `/autocomplete/bills` (= subscriptions), `/autocomplete/recurring`
- `/autocomplete/rules`, `/autocomplete/rule-groups`
- `/autocomplete/currencies`, `/autocomplete/currencies-with-code`
- `/autocomplete/object-groups`, `/autocomplete/piggy-banks`, `/autocomplete/piggy-banks-with-balance`
- `/autocomplete/transactions`, `/autocomplete/transactions-with-id`
- `/autocomplete/transaction-types`

When you need an ID and have a name, this is faster than walking the index.

## 5. Accounts

Account types: `asset`, `expense`, `revenue`, `liability` (with sub-types `loan`, `debt`, `mortgage`, `credit card`), `cash`, `initial-balance`, `reconciliation`.

| Verb | Path | Notes |
|---|---|---|
| `GET`    | `/accounts?type=asset&limit=100&date=2026-05-17` | `type` filter optional; `date` is the as-of date for balance |
| `POST`   | `/accounts` | Create — see body |
| `GET`    | `/accounts/{id}` | One account with current balance |
| `PUT`    | `/accounts/{id}` | Update — full or partial body |
| `DELETE` | `/accounts/{id}` | Soft-delete; child transactions stay but become orphaned in UI |
| `GET`    | `/accounts/{id}/transactions?type=withdrawal&start=..&end=..` | Tx for this account |
| `GET`    | `/accounts/{id}/piggy-banks` | Piggy banks linked to this asset account |
| `GET`    | `/accounts/{id}/attachments` | |

**Store body (minimum):**
```json
{
  "name": "Revolut EUR",
  "type": "asset",
  "currency_code": "EUR",
  "account_role": "defaultAsset",
  "opening_balance": "150.00",
  "opening_balance_date": "2026-01-01",
  "iban": "GB00REVO00000000000000",
  "include_net_worth": true,
  "active": true
}
```

`account_role` values for asset accounts: `defaultAsset`, `sharedAsset`, `savingAsset`, `ccAsset`, `cashWalletAsset`. For credit cards add `credit_card_type` (`monthlyFull`) and `monthly_payment_date`.

For liabilities the body adds `liability_type` (`loan`/`debt`/`mortgage`), `liability_direction` (`credit`=owed by user / `debit`=owed to user), `interest`, `interest_period`.

## 6. Transactions

The heart of the API. The model is **transaction group → transaction journal(s) → transactions (debit/credit pair)**, but the API hides this — you submit a *group* and Firefly creates the rest.

### Endpoints

| Verb | Path | Notes |
|---|---|---|
| `GET`    | `/transactions?type=all&start=..&end=..&limit=100&page=1` | Paginated list |
| `POST`   | `/transactions` | Create — see body |
| `GET`    | `/transactions/{groupId}` | One group with all journals |
| `PUT`    | `/transactions/{groupId}` | Update — full replacement of `transactions[]` |
| `DELETE` | `/transactions/{groupId}` | Soft-delete group |
| `GET`    | `/transactions/{groupId}/attachments` | |
| `GET`    | `/transactions/{groupId}/piggy-bank-events` | Piggy-bank effects this tx caused |
| `GET`    | `/transaction-journals/{journalId}` | Single journal (split) lookup |
| `DELETE` | `/transaction-journals/{journalId}` | Delete one split inside a group |
| `GET`    | `/transaction-journals/{journalId}/links` | Cross-references to other transactions |
| `POST`   | `/data/bulk/transactions` | Bulk patch — set category/tags/budget on many txs |

`type` filter values: `all`, `withdrawal`, `deposit`, `transfer`, `opening_balance`, `reconciliation`, `special` (the catch-all for the previous three).

### Store body

```json
{
  "error_if_duplicate_hash": true,
  "apply_rules": true,
  "fire_webhooks": true,
  "group_title": null,
  "transactions": [
    {
      "type": "withdrawal",
      "date": "2026-05-17",
      "amount": "12.34",
      "description": "Coffee",
      "source_id": 1,
      "destination_name": "Cafe Pina",
      "category_name": "Food & Drink",
      "tags": ["coffee", "morning"],
      "notes": "Espresso doppio",
      "external_id": "revolut:tx_abc123",
      "currency_code": "EUR",
      "foreign_amount": null,
      "foreign_currency_code": null,
      "budget_name": "Eating out",
      "bill_id": null,
      "reconciled": false
    }
  ]
}
```

Rules of thumb:
- `transactions[]` length > 1 ⇒ this is a **split**; `group_title` becomes the parent description.
- For a withdrawal: `source_id` (or `source_name`) is the asset account; `destination_id`/`_name` is the expense account (auto-created if name not found).
- For a deposit: source = revenue account, destination = asset.
- For a transfer: both source and destination are asset accounts.
- For foreign currency: set `currency_code` to the *foreign* currency of the transaction, and `foreign_amount`+`foreign_currency_code` to the asset account's currency conversion. Example: EUR account paying in USD ⇒ `amount:"100.00", currency_code:"USD", foreign_amount:"92.40", foreign_currency_code:"EUR"`.
- `external_id` is your idempotency key for re-import scenarios. With `error_if_duplicate_hash: true`, replays get `422 a115` instead of duplicates.
- All amounts are positive strings. The sign is implied by `type`.

### Update

`PUT /transactions/{groupId}` accepts the same envelope; provide only the journals you want to change. Each journal's `transaction_journal_id` identifies it; omit it to create a new split, include without other fields to delete.

### Bulk patch

```bash
POST /data/bulk/transactions
{
  "query": {"where": {"category_id": 5}},
  "update": {"category_id": 12}
}
```

The `query` is a Firefly search expression (same syntax as `/search/transactions`) OR a raw filter object. Bulk patch only supports updates of category, budget, tags. For anything else, fall back to per-tx `PUT`.

## 7. Categories, tags, budgets, bills, piggy banks

All five follow the same CRUD pattern: `GET /index`, `POST /index`, `GET/PUT/DELETE /{id}`.

### Categories — `/categories`
Plain labels. Stores per-period sums when queried with `?start=..&end=..`.
- `GET /categories/{id}/transactions`
- `GET /categories/{id}/attachments`

### Tags — `/tags`
Tags can have a date + lat/lng + zoom-level (geo-tag). Path supports `tagOrId` so you can `GET /tags/groceries` or `/tags/42`.

### Budgets — `/budgets`
Budgets are buckets; `available-budgets` are the monthly envelopes; `budget-limits` are the period caps.
- `GET  /budgets` / `POST /budgets`
- `GET  /budgets/{id}/transactions`
- `GET  /budgets/{id}/limits` → list budget limits
- `POST /budgets/{id}/limits` → set a limit `{start, end, amount, currency_code}`
- `PUT/DELETE /budget-limits/{id}` for the limit objects themselves
- `GET  /available-budgets` → the "money I want to spend this month" envelopes

### Bills (subscriptions) — `/bills` and identical alias `/subscriptions`
Recurring expectations of a payment (rent, Netflix). Firefly matches incoming transactions to bills via rule-like criteria.
```json
{
  "name": "Spotify",
  "amount_min": "9.99", "amount_max": "9.99",
  "date": "2026-01-15",
  "repeat_freq": "monthly",
  "skip": 0,
  "active": true,
  "currency_code": "EUR"
}
```
- `GET /bills/{id}/transactions` — matched txs
- `GET /bills/{id}/rules` — rules that fire bill matching
- `GET /bills/{id}/attachments`

### Piggy banks — `/piggy-banks`
Savings goals tied to one or more asset accounts.
```json
{
  "name": "Holiday",
  "accounts": [{"id": 1, "current_amount": "0"}],
  "target_amount": "1500.00",
  "start_date": "2026-01-01",
  "target_date": "2026-12-31",
  "object_group_title": "Travel"
}
```
- `GET /piggy-banks/{id}/events` — every deposit/withdrawal
- `GET /piggy-banks/{id}/accounts`, `/piggy-banks/{id}/attachments`

## 8. Recurrences — `/recurrences`

Templates that the cron expands into real transactions.
- `GET /recurrences` — list
- `POST /recurrences` — create
- `GET/PUT/DELETE /recurrences/{id}`
- `GET /recurrences/{id}/transactions` — instances created so far
- `POST /recurrences/{id}/trigger` — force one occurrence to fire now (idempotent: respects the recurrence's "next date")

Body sketch:
```json
{
  "title": "Rent",
  "first_date": "2026-06-01",
  "repetitions": [{"type": "monthly", "moment": "1", "skip": 0, "weekend": 1}],
  "transactions": [{
    "description": "Rent payment",
    "amount": "850",
    "type": "withdrawal",
    "currency_code": "EUR",
    "source_id": 1, "destination_name": "Landlord"
  }],
  "apply_rules": true,
  "active": true,
  "notes": ""
}
```

`weekend` values: `1` do nothing, `2` skip, `3` advance to Friday, `4` postpone to Monday.

## 9. Rules and rule groups

### Rule groups — `/rule-groups`
Containers for rules with an `order`.
- `GET /rule-groups/{id}/rules` — list rules inside
- `GET /rule-groups/{id}/test?start=..&end=..&accounts[]=1` — dry-run what would match
- `POST /rule-groups/{id}/trigger?start=..&end=..&accounts[]=1` — actually fire all rules on the date range

### Rules — `/rules`
- `GET /rules/validate-expression?expression=...` — sanity-check a search expression before saving
- `GET /rules/{id}/test?start=..&end=..` — dry-run
- `POST /rules/{id}/trigger?start=..&end=..` — fire one rule

Rule body shape:
```json
{
  "title": "Tag groceries",
  "rule_group_id": 1,
  "trigger": "store-journal",
  "strict": true,
  "stop_processing": false,
  "active": true,
  "triggers": [
    {"type": "destination_account_starts", "value": "Supermarket"}
  ],
  "actions": [
    {"type": "add_tag", "value": "groceries", "order": 1},
    {"type": "set_category", "value": "Food", "order": 2}
  ]
}
```
Common trigger types: `description_is`, `description_contains`, `description_starts`, `description_ends`, `amount_is`, `amount_more`, `amount_less`, `source_account_is`, `destination_account_is`, `transaction_type`, `has_any_tag`, `notes_contains`, `category_is`, `budget_is`, `currency_is`.
Common action types: `set_category`, `set_budget`, `add_tag`, `remove_tag`, `set_notes`, `append_notes`, `prepend_notes`, `set_description`, `link_to_bill`, `convert_withdrawal`, `convert_deposit`, `convert_transfer`, `delete_transaction`.

`trigger` (the rule-level field, not the array) values: `store-journal` (on creation), `update-journal` (on edit), `manual` (only when triggered explicitly).

### CLI alternative

For massive backfills use `php artisan firefly-iii:apply-rules` (see `references/cli.md`) — much faster than the API for thousands of transactions.

## 10. Webhooks — `/webhooks`

Outbound webhooks Firefly fires after specific events.
- `GET/POST /webhooks`
- `GET/PUT/DELETE /webhooks/{id}`
- `POST /webhooks/{id}/submit` — manually flush pending deliveries
- `POST /webhooks/{id}/trigger-transaction/{groupId}` — fire this webhook against an existing tx
- `GET /webhooks/{id}/messages` → list of generated payloads
- `GET /webhooks/{id}/messages/{msgId}` → one payload + state
- `DELETE /webhooks/{id}/messages/{msgId}` → clear
- `GET /webhooks/{id}/messages/{msgId}/attempts` → per-attempt delivery log

Body:
```json
{
  "title": "Notify HA",
  "active": true,
  "trigger": "STORE_TRANSACTION",
  "response": "TRANSACTIONS",
  "delivery": "JSON",
  "url": "https://hass.home/api/webhook/firefly_new_tx"
}
```
`trigger` values: `STORE_TRANSACTION`, `UPDATE_TRANSACTION`, `DESTROY_TRANSACTION`.
`response` values: `TRANSACTIONS`, `ACCOUNTS`, `NONE`.

The `webhook_secret` is autogenerated and exposed on the show endpoint — receivers can verify the `X-Firefly-Signature` header.

## 11. Attachments, links, object-groups, preferences, configuration

### Attachments — `/attachments`
Two-step upload:
1. `POST /attachments` with `{filename, attachable_type:"TransactionJournal", attachable_id:N, title, notes}` returns an attachment ID.
2. `POST /attachments/{id}/upload` with raw body bytes (`Content-Type: application/octet-stream`) uploads the file.
3. `GET /attachments/{id}/download` streams the file back.

### Transaction links — `/transaction-links` and `/link-types`
Link two transaction journals (refund, related, etc.). Link types are user-defined:
- `GET/POST /link-types` (POST is owner-only in single-user setups; default types come pre-installed)
- `GET/POST /transaction-links` `{link_type_id, inward_id, outward_id, notes}`

### Object groups — `/object-groups`
Tagging mechanism for piggy banks/bills (the "Travel" / "Recurring" groupings in the UI).
- `GET /object-groups` / `GET/PUT/DELETE /object-groups/{id}`

### Preferences — `/preferences`
Per-user settings stored as serialized JSON.
- `GET /preferences` — list all
- `GET /preferences/{name}` — read one (e.g. `currencyPreference`, `frontPageAccounts`, `viewRange`)
- `PUT /preferences/{name}` — `{data: <json-encoded value>}`
- `POST /preferences` — create new

### Configuration — `/configuration`
System-level config — admin only.
- `GET /configuration` — list (e.g. `permission_update_check`, `last_update_check`, `single_user_mode`, `is_demo_site`)
- `GET /configuration/{key}`
- `PUT /configuration/{key}` — `{value: ...}` (only for "dynamic" keys, i.e. not the immutable ones)

## 12. Currencies and exchange rates

### Currencies — `/currencies`
- `GET /currencies` — list (each has `enabled`, `default`)
- `POST /currencies` `{code, name, symbol, decimal_places, enabled}`
- `GET /currencies/{code}`, `GET /currencies/primary` (= default)
- `POST /currencies/{code}/enable` / `/disable`
- `POST /currencies/{code}/primary` — set as primary (formerly "default")
- `PUT /currencies/{code}` — rename/relabel
- `DELETE /currencies/{code}` — only if no records reference it
- Many `/currencies/{code}/<resource>` listing endpoints: `accounts`, `bills`, `budget-limits`, `available-budgets`, `cer`, `recurrences`, `rules`, `transactions`

### Exchange rates — `/exchange-rates`
- `GET /exchange-rates?from=EUR&to=USD&date=...&limit=...`
- `GET /exchange-rates/{from}/{to}` — list all dated rates
- `GET /exchange-rates/{from}/{to}/{YYYY-MM-DD}` — one rate
- `GET /exchange-rates/{id}` — by internal id
- `POST /exchange-rates` `{from_currency_code, to_currency_code, date, rate}`
- `POST /exchange-rates/by-date/{date}` — batch by date
- `POST /exchange-rates/by-currencies/{from}/{to}` — batch for a pair
- `PUT /exchange-rates/{id}` / `PUT /exchange-rates/{from}/{to}/{date}` — update
- `DELETE /exchange-rates/{from}/{to}` — delete all for a pair
- `DELETE /exchange-rates/{from}/{to}/{date}` — delete one

## 13. Charts, insight, reports

### Charts — `/chart/*`
Pre-aggregated series for dashboards.
- `GET /chart/balance/balance?start=..&end=..&accounts[]=1&accounts[]=2` — line series
- `GET /chart/account/overview?start=..&end=..&accounts[]=...` — per-account net change
- `GET /chart/budget/overview?start=..&end=..` — budget consumption
- `GET /chart/category/overview?start=..&end=..` — top categories

### Insight — `/insight/*`
Breakdowns by dimension. Three top groups: `expense`, `income`, `transfer`.

For **expense** (`/insight/expense/...`):
- `/expense` — per expense-account spend
- `/asset` — per asset-account net outflow
- `/total?start=..&end=..` — total in period
- `/bill` / `/no-bill` — spending tied to bills vs. ad-hoc
- `/budget` / `/no-budget` — budgeted vs. unbudgeted
- `/category` / `/no-category`
- `/tag` / `/no-tag`

For **income** (`/insight/income/...`): `/revenue`, `/asset`, `/total`, `/category`, `/no-category`, `/tag`, `/no-tag`.

For **transfer** (`/insight/transfer/...`): `/asset`, `/category`, `/no-category`, `/tag`, `/no-tag`, `/total`.

All take `start`, `end`; many take filter arrays (`accounts[]`, `tags[]`, `budgets[]`, etc.).

### Reports
No dedicated `/reports` endpoint — build reports by combining `/summary/basic`, `/insight/*`, and `/chart/*`. The browser UI does exactly this.

## 14. Data export, destroy, purge, bulk update

### Export — `/data/export/*` (read-only, returns CSV/JSON)
- `/data/export/accounts`
- `/data/export/transactions?start=..&end=..&accounts[]=...`
- `/data/export/budgets`, `/data/export/bills` (alias `/subscriptions`), `/data/export/categories`, `/data/export/tags`
- `/data/export/piggy-banks`, `/data/export/recurring`, `/data/export/rules`

Each takes `?type=csv|json` (default csv). Headers: `Content-Disposition: attachment`. Pipe to a file:
```bash
ff-api.sh GET '/api/v1/data/export/transactions?start=2026-01-01&end=2026-12-31&type=csv' > tx.csv
```

For full system export use the **CLI** `firefly-iii:export-data` — it can dump everything in one go.

### Destroy — `DELETE /data/destroy?objects=<type>`
Wholesale wipe by category. **Destructive** — confirm with the user first.
`objects` values: `budgets`, `bills`, `piggy_banks`, `rules`, `recurring`, `categories`, `tags`, `object_groups`, `not_assets_liabilities`, `accounts` (asset accounts cascade — wipes everything), `asset_accounts`, `expense_accounts`, `revenue_accounts`, `liabilities`, `transactions`, `withdrawals`, `deposits`, `transfers`.

### Purge — `DELETE /data/purge`
Permanently removes anything currently soft-deleted (transactions, accounts, etc.). Run after a `correct-database` if you want to free DB space.

### Bulk update — `POST /data/bulk/transactions`
See [transactions](#6-transactions).

## 15. Users, user-groups, batch, system

### Users — `/users` (admin only)
- `GET /users` / `POST /users`
- `GET/PUT/DELETE /users/{id}`

`POST /users` requires `{email, role, password (optional)}`. Roles: `owner`, `demo`, `null`. Multi-user is feature-flagged via the user-groups system below.

### User groups — `/user-groups`
- `GET /user-groups` / `GET /user-groups/{id}` / `PUT /user-groups/{id}`
- Group memberships are managed through the UI only at present.

### Batch — `/batch`
- `POST /batch/finish` — bookkeeping endpoint used by the importer to mark a batch complete.

### System — cron + about
- `GET /cron/{cliToken}` — fires the cron over HTTP (matches the `STATIC_CRON_TOKEN` env). Not bearer-authed. Used by the scheduler container's wget cron.
- `GET /about` / `/about/user` — see [section 4](#4-about-summary-search-autocomplete).
