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
UPDATE transaction_groups SET deleted_at = NULL WHERE ...;
UPDATE transaction_journals SET deleted_at = NULL WHERE ...;
UPDATE transactions SET deleted_at = NULL WHERE ...;
``` 

## Updating the Importer Config

Swarm configs are immutable. Scale down first to release the lock, then recreate.

```bash
scp services/firefly/config/config.json pi@pi.local:/tmp/importer_config.json
ssh pi@pi.local
docker service scale firefly_importer=0
docker config rm firefly_importer_config
docker config create firefly_importer_config /tmp/importer_config.json && rm /tmp/importer_config.json
docker service scale firefly_importer=1
```

> `config.json` is gitignored — contains `access_token`, never commit it.
