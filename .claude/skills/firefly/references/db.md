# Firefly III database reference

Direct database operations on the MariaDB instance `firefly_db`. Read this **only** when the API and CLI cannot recover the situation. Every SQL mutation must be followed by `firefly-iii:correct-database`, `cache:clear`, and `firefly-iii:refresh-running-balance` — otherwise Firefly's in-memory caches and computed balances diverge from the row state.

## Connecting

The DB password lives in the `firefly_db_password` swarm secret, mounted in both the app and db containers. Pull it from the app:

```bash
ssh giorgiocaizzi@pi.local '
  APP=$(docker ps --filter "label=com.docker.swarm.service.name=firefly_app" --format "{{.Names}}" | head -1)
  DB=$(docker ps --filter "label=com.docker.swarm.service.name=firefly_db" --format "{{.Names}}" | head -1)
  DB_PASS=$(docker exec "$APP" cat /run/secrets/db_password)
  docker exec -it "$DB" mariadb -u firefly -p"$DB_PASS" firefly
'
```

For a one-shot query, swap `-it` for `-e "SELECT ...;"`.

## Schema cheat-sheet

Firefly groups every change to money as a three-level structure:

```
transaction_groups        (1)  ── parent, holds title for splits
  └── transaction_journals (1+) ── one per split; holds description, date, type
        └── transactions   (2+) ── debit + credit rows
              └── account_id, amount, currency, foreign_amount, ...
```

**Transaction types** (`transaction_journals.transaction_type_id` → `transaction_types.id`):

| id | type |
|---|---|
| 1 | Deposit |
| 2 | Invalid |
| 3 | Liability credit |
| 4 | Opening balance |
| 5 | Reconciliation |
| 6 | Transfer |
| 7 | Withdrawal |

**Account types** (`accounts.account_type_id` → `account_types.id`):

| id | type |
|---|---|
| 1 | Default account |
| 2 | Cash account |
| 3 | Asset account |
| 4 | Expense account |
| 5 | Revenue account |
| 6 | Initial balance account |
| 7 | Beneficiary account |
| 8 | Import account |
| 9 | Loan |
| 10 | Reconciliation account |
| 11 | Credit card |
| 12 | Debt |
| 13 | Mortgage |
| 14 | Liability |
| 15 | Liability credit account |

**Other essential tables:**

| Table | Holds |
|---|---|
| `users` | Single row in single-user mode (`id=1`) |
| `accounts` | All account types |
| `account_meta` | KV side-table for account extras (`account_role`, `currency_id`, `account_number`, `BIC`, `IBAN_holder`, …) |
| `transaction_currencies` | `EUR`, `USD`, … (used by `currency_id`) |
| `categories`, `budgets`, `budget_limits`, `available_budgets` | |
| `tags`, `tag_transaction_journal` (M2M) | |
| `bills` | Subscriptions |
| `piggy_banks`, `piggy_bank_events`, `piggy_bank_repetitions`, `account_piggy_bank` | Goals + per-account split |
| `recurrences`, `recurrences_meta`, `recurrences_repetitions`, `recurrences_transactions` | Recurring tx |
| `rule_groups`, `rules`, `rule_triggers`, `rule_actions` | |
| `journal_links`, `link_types` | Cross-references between journals |
| `attachments` | DB row + file in `storage/upload` |
| `journal_meta` | KV side-table for journal extras (`external_id`, `original-source`, geo, etc.) |
| `webhooks`, `webhook_messages`, `webhook_attempts` | |
| `oauth_*` | Passport tables (clients, tokens, refresh tokens) |
| `preferences` | Per-user serialised JSON settings |
| `configuration` | System-level KV |
| `failed_jobs`, `jobs` | Laravel queue (sync queue by default; usually empty) |
| `migrations` | Laravel migration state |

## Soft-delete semantics — the critical invariant

`transaction_groups`, `transaction_journals`, `transactions`, `accounts`, and most user-owned tables carry a `deleted_at TIMESTAMP NULL`. `NULL` = active; non-null = soft-deleted.

**Firefly enforces parent-child consistency.** On boot and via `firefly-iii:correct-database`, if a parent is soft-deleted, the cascade re-deletes the children — *even if you restored them*. If you restore in the wrong order, your fix is silently reverted.

**Always restore top-down: groups → journals → transactions.** Always delete bottom-up if you must.

## Rollback pattern (restore a set of soft-deleted transactions)

Use a deterministic match key — `description LIKE`, an `external_id` in `journal_meta`, or an explicit list of `transaction_group_id`s. Below uses a description pattern; substitute your own.

```sql
-- 1. Restore parent groups (idempotent — only un-deletes already-deleted rows)
UPDATE transaction_groups
SET    deleted_at = NULL, updated_at = NOW()
WHERE  deleted_at IS NOT NULL
AND    EXISTS (
         SELECT 1 FROM transaction_journals tj
         WHERE  tj.transaction_group_id = transaction_groups.id
         AND    tj.description LIKE '%<pattern>%'
       );

-- 2. Restore the journals
UPDATE transaction_journals
SET    deleted_at = NULL, updated_at = NOW()
WHERE  deleted_at IS NOT NULL
AND    description LIKE '%<pattern>%';

-- 3. Restore the underlying transaction rows
UPDATE transactions t
SET    t.deleted_at = NULL, t.updated_at = NOW()
WHERE  t.deleted_at IS NOT NULL
AND    EXISTS (
         SELECT 1 FROM transaction_journals tj
         WHERE  tj.id = t.transaction_journal_id
         AND    tj.description LIKE '%<pattern>%'
       );
```

Then, **always**, from the app container:
```bash
scripts/ff-artisan.sh cache:clear
scripts/ff-artisan.sh firefly-iii:correct-database
scripts/ff-artisan.sh firefly-iii:refresh-running-balance --force
```

## Other useful direct queries

### Find duplicates by external_id

```sql
SELECT jm.data AS external_id, COUNT(*) c, GROUP_CONCAT(jm.transaction_journal_id) journals
FROM   journal_meta jm
WHERE  jm.name = 'external_id'
GROUP  BY jm.data
HAVING c > 1;
```

### Orphaned `transactions` (parent journal missing or deleted)

```sql
SELECT t.id, t.transaction_journal_id, t.account_id, t.amount
FROM   transactions t
LEFT   JOIN transaction_journals tj ON tj.id = t.transaction_journal_id
WHERE  t.deleted_at IS NULL
AND    (tj.id IS NULL OR tj.deleted_at IS NOT NULL);
```

Fix via `firefly-iii:removes-orphaned-transactions` (or the umbrella `correct-database`).

### Journals whose two `transactions` rows don't sum to zero

```sql
SELECT t.transaction_journal_id, ROUND(SUM(t.amount), 4) total
FROM   transactions t
WHERE  t.deleted_at IS NULL
GROUP  BY t.transaction_journal_id
HAVING total <> 0;
```

Fix via `firefly-iii:corrects-uneven-amount`.

### Spend per asset account this month

```sql
SELECT a.id, a.name, SUM(t.amount) AS net_change_eur
FROM   transactions t
JOIN   transaction_journals tj ON tj.id = t.transaction_journal_id
JOIN   accounts a ON a.id = t.account_id
JOIN   account_types at ON at.id = a.account_type_id
WHERE  at.type = 'Asset account'
AND    tj.date >= '2026-05-01' AND tj.date < '2026-06-01'
AND    tj.deleted_at IS NULL AND t.deleted_at IS NULL
GROUP  BY a.id, a.name;
```

### List Personal Access Tokens (debug-only — does not expose the JWT)

```sql
SELECT id, user_id, client_id, name, scopes, revoked, expires_at, created_at
FROM   oauth_access_tokens
WHERE  revoked = 0;
```

### Find the user's Passport "Personal Access Client"

```sql
SELECT * FROM oauth_clients WHERE personal_access_client = 1;
```

If this row is missing after an OAuth wipe, Firefly's UI won't let you create new Personal Access Tokens. Run `php artisan passport:client --personal` to recreate.

## Backups + restore notes

- The canonical backup is the MariaDB dump (see `workflows.md` workflow 16). Restore via:
  ```bash
  gunzip -c firefly-db.sql.gz | docker exec -i $DB mariadb -u firefly -p"$DB_PASS" firefly
  ```
- File attachments live on the `firefly_upload` volume. Their DB rows have a `hash` column (SHA-256) — after restore run `firefly-iii:scan-attachments` so Firefly re-checksums and re-mimes.
- OAuth keys (`storage/oauth-{public,private}.key`) live on the `firefly_storage` named volume, so they survive container recreate and Personal Access Tokens stay valid across redeploys. If the volume is lost (e.g. wiped in a recovery), all PATs become invalid simultaneously; rotate the `firefly_access_token` secret via the procedure in `services/firefly/README.md` (§ *Rotating `firefly_access_token`*).
