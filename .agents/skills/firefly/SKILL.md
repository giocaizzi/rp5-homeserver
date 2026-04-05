---
name: firefly
description: Firefly runbook. Use this when working with Firefly app.
---

# Firefly

Firefly is a personal finance manager.


## Firefly Database

Firefly uses MariaDB for its database.

### Database Structure

**Hierarchy:** `transaction_groups` → `transaction_journals` → `transactions`

Each transaction has:
- **1 transaction_group** (parent) - groups related journals
- **1 transaction_journal** - contains metadata (description, type, date)
- **2+ transactions** - actual debit/credit entries (amount, account_id)

**Soft-Delete Behavior:**
- All three tables have `deleted_at` field (NULL = active, timestamp = deleted)
- Firefly enforces parent-child consistency: if parent is soft-deleted, children are auto-deleted on restart
- **Critical:** When restoring soft-deleted records, restore ALL levels (groups → journals → transactions)

**Transaction Types (transaction_type_id):**
- 1 = Deposit
- 2 = Invalid
- 3 = Liability credit
- 4 = Opening balance
- 5 = Reconciliation
- 6 = Transfer
- 7 = Withdrawal

**Rollback Pattern:**
```sql
-- Always restore in this order:
UPDATE transaction_groups SET deleted_at = NULL, updated_at = NOW()
WHERE deleted_at IS NOT NULL AND EXISTS (
  SELECT 1 FROM transaction_journals tj
  WHERE tj.transaction_group_id = transaction_groups.id AND tj.description LIKE '%<pattern>%'
);
UPDATE transaction_journals SET deleted_at = NULL, updated_at = NOW()
WHERE deleted_at IS NOT NULL AND description LIKE '%<pattern>%';
UPDATE transactions t SET t.deleted_at = NULL, t.updated_at = NOW()
WHERE t.deleted_at IS NOT NULL AND EXISTS (
  SELECT 1 FROM transaction_journals tj
  WHERE tj.id = t.transaction_journal_id AND tj.description LIKE '%<pattern>%'
);
```

**Post-restore commands (run in app container):**
```bash
php artisan cache:clear
php artisan firefly-iii:correct-database
php artisan firefly-iii:refresh-running-balance
```

**Connect to DB from app container (password via secret):**
```bash
APP=$(docker ps --filter 'label=com.docker.swarm.service.name=firefly_app' --format '{{.Names}}' | head -1)
DB=$(docker ps --filter 'label=com.docker.swarm.service.name=firefly_db' --format '{{.Names}}' | head -1)
DB_PASS=$(docker exec $APP cat /run/secrets/db_password)
docker exec $DB mariadb -u firefly -p"$DB_PASS" firefly -e "SELECT ...;"
```

## Updating the Importer Config

Swarm configs are immutable. Scale down first to release the lock, then recreate.

Scaling to 0 is **not** enough — the service definition still holds a reference. Use `--config-rm`/`--config-add` to detach/reattach.

```bash
scp services/firefly/config/config.json pi@pi.local:/tmp/importer_config.json
ssh pi@pi.local "
  docker service update --config-rm firefly_importer_config firefly_importer &&
  docker config rm firefly_importer_config &&
  docker config create firefly_importer_config /tmp/importer_config.json &&
  rm /tmp/importer_config.json &&
  docker service update --config-add source=firefly_importer_config,target=/var/www/html/import/config.json,mode=0444 firefly_importer &&
  docker service scale firefly_importer=1
"
```

> `config.json` is gitignored — contains `access_token`, never commit it.

## Triggering an Import Manually

The `/autoimport` endpoint requires an `Authorization: Bearer` header with the Firefly III personal access token (`firefly_access_token` secret). Read it from the scheduler container (which holds the secret), then POST to the importer:

```bash
ssh pi@pi.local "
  SCHEDULER=\$(docker ps --filter 'label=com.docker.swarm.service.name=firefly_scheduler' --format '{{.Names}}' | head -1)
  ACCESS_TOKEN=\$(docker exec \$SCHEDULER cat /run/secrets/firefly_access_token)

  IMPORTER=\$(docker ps --filter 'label=com.docker.swarm.service.name=firefly_importer' --format '{{.Names}}' | head -1)
  AUTO_IMPORT_SECRET=\$(docker exec \$IMPORTER cat /run/secrets/auto_import_secret)

  docker exec \$IMPORTER curl -s -X POST \
    -H 'Accept: application/json' \
    -H \"Authorization: Bearer \${ACCESS_TOKEN}\" \
    \"http://localhost:8080/autoimport?directory=/var/www/html/import&secret=\${AUTO_IMPORT_SECRET}\"
"
```

Expected response: `{"message":"Seems to have worked!"}` (HTTP 200). Duplicate transaction errors in logs (`a115`) are non-fatal — they indicate already-imported data in the date range.
