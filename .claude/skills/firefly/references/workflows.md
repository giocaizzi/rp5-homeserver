# End-to-end workflows

Recipes that string together API calls, CLI commands, and (rarely) SQL. Each one is a complete operational script — copy, fill in the placeholders, run. All commands assume `scripts/ff-api.sh` and `scripts/ff-artisan.sh` are on `$PATH` or invoked with their relative path.

## Table of contents
- [1. First-time setup of a Personal Access Token](#1-first-time-setup-of-a-personal-access-token)
- [2. Create an asset account and an opening balance](#2-create-an-asset-account-and-an-opening-balance)
- [3. Record a single transaction (withdrawal / deposit / transfer)](#3-record-a-single-transaction-withdrawal--deposit--transfer)
- [4. Split a transaction](#4-split-a-transaction)
- [5. Record a foreign-currency transaction](#5-record-a-foreign-currency-transaction)
- [6. Bulk import historical CSV via the API (small files)](#6-bulk-import-historical-csv-via-the-api-small-files)
- [7. Bulk import via the Data Importer (large files / Lunch Flow)](#7-bulk-import-via-the-data-importer-large-files--lunch-flow)
- [8. Set up a category, budget, and limit; assign past transactions](#8-set-up-a-category-budget-and-limit-assign-past-transactions)
- [9. Set up a bill (subscription) and let rules auto-match](#9-set-up-a-bill-subscription-and-let-rules-auto-match)
- [10. Create a recurring transaction](#10-create-a-recurring-transaction)
- [11. Build a tagging rule and back-fill it](#11-build-a-tagging-rule-and-back-fill-it)
- [12. Reconcile an account](#12-reconcile-an-account)
- [13. Save toward a piggy bank](#13-save-toward-a-piggy-bank)
- [14. Subscribe to webhook events](#14-subscribe-to-webhook-events)
- [15. Pull a monthly report](#15-pull-a-monthly-report)
- [16. Full data export + offsite backup](#16-full-data-export--offsite-backup)
- [17. Disaster recovery: restore + validate](#17-disaster-recovery-restore--validate)

---

## 1. First-time setup of a Personal Access Token

After deploying Firefly and registering the first user:

1. UI → **Options → Profile → OAuth → Personal Access Tokens → Create New Token**. Give it any name. Copy the JWT — it is shown **once**.
2. Store on the Pi as the `firefly_access_token` secret:
   ```bash
   echo -n "eyJ0eXAi..." | ssh giorgiocaizzi@pi.local 'docker secret create firefly_access_token -'
   ```
3. Restart the scheduler so it re-mounts the secret:
   ```bash
   ssh giorgiocaizzi@pi.local 'docker service update --force firefly_scheduler'
   ```
4. Verify:
   ```bash
   scripts/ff-api.sh GET /api/v1/about/user
   ```
   Expect a 200 with `data.attributes.email`.

If you ever lose the token, rotate by deleting it in the UI, repeating step 1, and `docker secret rm firefly_access_token` + recreate.

## 2. Create an asset account and an opening balance

```bash
scripts/ff-api.sh POST /api/v1/accounts '{
  "name": "Revolut EUR",
  "type": "asset",
  "currency_code": "EUR",
  "account_role": "defaultAsset",
  "opening_balance": "150.00",
  "opening_balance_date": "2026-01-01",
  "iban": "GB00REVO00000000000000",
  "active": true,
  "include_net_worth": true
}'
```

The opening balance is recorded as a special transaction (`transaction_type_id=4`). To change it later, fetch the account → follow `links.transactions` → `PUT` that transaction group.

## 3. Record a single transaction (withdrawal / deposit / transfer)

The shape is identical; only `type` and source/destination roles change.

**Withdrawal** (asset → expense):
```bash
scripts/ff-api.sh POST /api/v1/transactions '{
  "error_if_duplicate_hash": true,
  "apply_rules": true,
  "fire_webhooks": true,
  "transactions": [{
    "type": "withdrawal",
    "date": "2026-05-17",
    "amount": "4.20",
    "description": "Espresso",
    "source_id": 1,
    "destination_name": "Cafe Pina",
    "category_name": "Food & Drink",
    "currency_code": "EUR",
    "tags": ["coffee"]
  }]
}'
```

**Deposit** (revenue → asset):
```json
{"type":"deposit","date":"2026-05-17","amount":"2500.00","description":"Salary",
 "source_name":"Acme Corp","destination_id":1,"category_name":"Salary","currency_code":"EUR"}
```

**Transfer** (asset → asset):
```json
{"type":"transfer","date":"2026-05-17","amount":"500.00","description":"Move to savings",
 "source_id":1,"destination_id":2,"currency_code":"EUR"}
```

Send all of them inside `{"transactions":[...]}`. `external_id` is the idempotency key; set it to the upstream source's transaction ID when importing.

## 4. Split a transaction

A receipt that combines groceries and a coffee: one trip to the store, two journals inside one group.

```bash
scripts/ff-api.sh POST /api/v1/transactions '{
  "error_if_duplicate_hash": true,
  "apply_rules": true,
  "group_title": "Lidl trip — 17 May",
  "transactions": [
    {
      "type": "withdrawal", "date": "2026-05-17",
      "amount": "42.10", "description": "Groceries",
      "source_id": 1, "destination_name": "Lidl",
      "category_name": "Groceries", "currency_code": "EUR"
    },
    {
      "type": "withdrawal", "date": "2026-05-17",
      "amount": "1.90", "description": "Coffee",
      "source_id": 1, "destination_name": "Lidl",
      "category_name": "Food & Drink", "currency_code": "EUR"
    }
  ]
}'
```

The group totals to €44.00 from account 1; the per-journal categories let budgets and reports break out the spend.

## 5. Record a foreign-currency transaction

EUR account paying USD (e.g. €92.40 charged for a $100 purchase):

```json
{
  "type": "withdrawal",
  "date": "2026-05-17",
  "amount": "100.00",             // foreign side: USD
  "currency_code": "USD",
  "foreign_amount": "92.40",      // home side: EUR
  "foreign_currency_code": "EUR",
  "description": "GitHub Copilot",
  "source_id": 1,                 // the EUR account
  "destination_name": "GitHub"
}
```

Rule of thumb: `currency_code` + `amount` are what the transaction *was* (foreign); `foreign_*` is what your account *paid* (home). The asset account's currency dictates which side is home — see `/accounts/{id}` `attributes.currency_code`.

## 6. Bulk import historical CSV via the API (small files)

For up to ~1000 rows. Larger goes through the Data Importer (see workflow 7).

1. Use Python/jq to convert your CSV to a stream of `POST /api/v1/transactions` payloads, one per row. Set `external_id` to a stable key from your CSV so reruns are no-ops.
2. Disable rules during the bulk (`apply_rules: false`) to avoid the action storm.
3. POST each payload; treat `422 a115` (duplicate hash) as success.
4. After the bulk, fire the rule groups once:
   ```bash
   scripts/ff-api.sh POST '/api/v1/rule-groups/1/trigger?start=2026-01-01&end=2026-05-17'
   ```
5. Refresh balances:
   ```bash
   scripts/ff-artisan.sh firefly-iii:refresh-running-balance
   ```

## 7. Bulk import via the Data Importer (large files / Lunch Flow)

Use this for thousands of rows, or for Lunch Flow / Spectre / GoCardless feeds. Full procedure in `references/importer.md`; summary:

1. Generate the import **config** by uploading a sample CSV through `https://firefly-importer.home` UI, then **Download configuration**.
2. Drop the JSON config into the swarm and rotate the importer's `firefly_importer_config` Swarm config (commands in `references/importer.md`).
3. Place data files in `/var/www/html/import/` inside the importer container (mounted from `firefly_upload`).
4. Trigger:
   ```bash
   scripts/ff-api.sh POST '/autoimport?directory=/var/www/html/import&secret=<auto_import_secret>'
   ```
   (use the dedicated `ff-importer-api` invocation in `references/importer.md`)
5. Watch logs: `ssh giorgiocaizzi@pi.local 'docker service logs --tail 200 -f firefly_importer'`.

## 8. Set up a category, budget, and limit; assign past transactions

```bash
# 1. Category
CAT=$(scripts/ff-api.sh POST /api/v1/categories '{"name":"Groceries"}' | jq -r '.data.id')

# 2. Budget (named bucket)
BUD=$(scripts/ff-api.sh POST /api/v1/budgets '{"name":"Food","active":true}' | jq -r '.data.id')

# 3. Budget limit for May
scripts/ff-api.sh POST "/api/v1/budgets/$BUD/limits" '{
  "start":"2026-05-01","end":"2026-05-31",
  "amount":"400.00","currency_code":"EUR"
}'

# 4. Tag historical transactions with this category via bulk patch
scripts/ff-api.sh POST /api/v1/data/bulk/transactions "$(jq -n --arg q "category:none destination:Lidl" --argjson c "$CAT" '
  {query:{search:$q},update:{category_id:$c}}')"
```

After the bulk update, `GET /api/v1/insight/expense/category?start=2026-05-01&end=2026-05-31` reflects the change.

## 9. Set up a bill (subscription) and let rules auto-match

Bills are "expected payments". Firefly only auto-matches if a rule links transactions to the bill.

```bash
# 1. Create the bill
BILL=$(scripts/ff-api.sh POST /api/v1/bills '{
  "name":"Netflix","amount_min":"12.99","amount_max":"13.99",
  "date":"2026-01-15","repeat_freq":"monthly","skip":0,
  "currency_code":"EUR","active":true
}' | jq -r '.data.id')

# 2. Create a rule that links matching transactions to the bill
scripts/ff-api.sh POST /api/v1/rules "$(jq -n --argjson b "$BILL" '{
  "title":"Auto-link Netflix",
  "rule_group_id":1,
  "trigger":"store-journal",
  "strict":true,"stop_processing":false,"active":true,
  "triggers":[
    {"type":"description_contains","value":"NETFLIX"},
    {"type":"amount_more","value":"12.00"},
    {"type":"amount_less","value":"14.00"}
  ],
  "actions":[
    {"type":"link_to_bill","value":($b|tostring),"order":1}
  ]
}')"

# 3. Back-fill against existing transactions
scripts/ff-api.sh POST "/api/v1/rule-groups/1/trigger?start=2026-01-01&end=2026-05-17"
```

## 10. Create a recurring transaction

```bash
scripts/ff-api.sh POST /api/v1/recurrences '{
  "title":"Rent",
  "first_date":"2026-06-01",
  "active":true,
  "apply_rules":true,
  "repetitions":[{"type":"monthly","moment":"1","skip":0,"weekend":1}],
  "transactions":[{
    "description":"Rent payment",
    "amount":"850.00",
    "type":"withdrawal",
    "currency_code":"EUR",
    "source_id":1,
    "destination_name":"Landlord",
    "category_name":"Housing",
    "tags":["recurring"]
  }],
  "notes":""
}'
```

Force a one-off run (e.g. to back-fill a missed cycle):
```bash
scripts/ff-api.sh POST /api/v1/recurrences/$REC_ID/trigger
```

Recurrences are realised by `firefly-iii:cron`. To run cron for a specific past date:
```bash
scripts/ff-artisan.sh firefly-iii:cron --date=2026-06-01 --force
```

## 11. Build a tagging rule and back-fill it

Tag every Uber/Lyft as `transport`:

```bash
scripts/ff-api.sh POST /api/v1/rules '{
  "title":"Tag ridesharing",
  "rule_group_id":1,
  "trigger":"store-journal",
  "strict":false,
  "stop_processing":false,
  "active":true,
  "triggers":[
    {"type":"description_contains","value":"UBER"},
    {"type":"description_contains","value":"LYFT"}
  ],
  "actions":[
    {"type":"add_tag","value":"transport","order":1},
    {"type":"set_category","value":"Transport","order":2}
  ]
}'
```

Note `strict:false` — it's an OR rule (matches either trigger). With `strict:true` all triggers must hit. Back-fill:
```bash
scripts/ff-api.sh POST "/api/v1/rules/$RULE_ID/trigger?start=2026-01-01&end=2026-05-17"
```

For huge ranges, use the CLI `firefly-iii:apply-rules --rules=$RULE_ID` instead — it's faster and uses less memory.

## 12. Reconcile an account

Reconciliation = "as of date X, the account balance should be Y; create a balancing journal if not."

The API does not expose a dedicated reconciliation endpoint; create a reconciliation transaction directly:
```bash
scripts/ff-api.sh POST /api/v1/transactions '{
  "transactions":[{
    "type":"reconciliation",
    "date":"2026-05-17",
    "amount":"3.45",
    "description":"Reconciliation 2026-05-17",
    "source_id":1,
    "destination_name":"Reconciliation account",
    "reconciled":true
  }]
}'
```

The sign convention: amount is positive, direction is implied by `source`/`destination` (asset → reconciliation = correction down; reconciliation → asset = correction up). Firefly flags reconciled journals and dims them in the UI.

## 13. Save toward a piggy bank

```bash
# Create piggy bank
PIG=$(scripts/ff-api.sh POST /api/v1/piggy-banks '{
  "name":"Iceland trip",
  "accounts":[{"id":1,"current_amount":"0"}],
  "target_amount":"1500.00",
  "start_date":"2026-01-01","target_date":"2026-12-31"
}' | jq -r '.data.id')

# Add €100 toward it (creates a piggy-bank event, no new tx)
# Note: piggy-bank balance changes happen via piggy-bank events, which Firefly
# exposes through transaction notes (`add_amount` field on the transaction store).
# The supported way is to record a transfer into the goal-linked account and
# mark the piggy bank via the journal note "piggyBank=<id>:+100".
```

Piggy banks reflect intentions, not money movements — the cash stays in the asset account. Firefly recalculates the piggy total nightly via `firefly-iii:corrects-piggy-banks`.

## 14. Subscribe to webhook events

Wire Firefly to your home automation:
```bash
scripts/ff-api.sh POST /api/v1/webhooks '{
  "title":"Notify HA on new transaction",
  "active":true,
  "trigger":"STORE_TRANSACTION",
  "response":"TRANSACTIONS",
  "delivery":"JSON",
  "url":"https://hass.home/api/webhook/firefly_new_tx"
}'
```

Inspect deliveries:
```bash
scripts/ff-api.sh GET /api/v1/webhooks/$WH_ID/messages
scripts/ff-api.sh GET /api/v1/webhooks/$WH_ID/messages/$MSG_ID/attempts
```

Receivers should verify the `X-Firefly-Signature` header (HMAC-SHA3-256 of the body using the webhook secret).

## 15. Pull a monthly report

Numbers for May 2026:

```bash
START=2026-05-01; END=2026-05-31; CUR=EUR

scripts/ff-api.sh GET "/api/v1/summary/basic?start=$START&end=$END&currency_code=$CUR"

# Per-category spend
scripts/ff-api.sh GET "/api/v1/insight/expense/category?start=$START&end=$END"

# Per-budget spend vs. limit
scripts/ff-api.sh GET "/api/v1/insight/expense/budget?start=$START&end=$END"

# Net per asset account
scripts/ff-api.sh GET "/api/v1/chart/account/overview?start=$START&end=$END"
```

For a CSV instead of JSON aggregations:
```bash
scripts/ff-api.sh GET "/api/v1/data/export/transactions?start=$START&end=$END&type=csv" > may.csv
```

## 16. Full data export + offsite backup

```bash
# 1. CLI export (everything)
scripts/ff-artisan.sh firefly-iii:export-data \
  --token=$(ssh giorgiocaizzi@pi.local 'docker exec $(docker ps -qf label=com.docker.swarm.service.name=firefly_scheduler | head -1) cat /run/secrets/firefly_access_token') \
  --export_directory=/var/www/html/storage/upload \
  --export-transactions --export-accounts --export-budgets \
  --export-categories --export-tags --export-recurring \
  --export-rules --export-subscriptions --export-piggies --force

# 2. Pull files from the volume
ssh giorgiocaizzi@pi.local 'sudo tar czf /tmp/firefly-export.tar.gz -C /var/lib/docker/volumes/firefly_firefly_upload/_data .'
scp giorgiocaizzi@pi.local:/tmp/firefly-export.tar.gz ./
ssh giorgiocaizzi@pi.local 'rm /tmp/firefly-export.tar.gz'

# 3. DB dump (canonical backup)
ssh giorgiocaizzi@pi.local '
  APP=$(docker ps -qf label=com.docker.swarm.service.name=firefly_app | head -1)
  DB=$(docker ps -qf label=com.docker.swarm.service.name=firefly_db | head -1)
  DB_PASS=$(docker exec $APP cat /run/secrets/db_password)
  docker exec $DB mariadb-dump -u firefly -p"$DB_PASS" firefly | gzip > /tmp/firefly-db.sql.gz
'
scp giorgiocaizzi@pi.local:/tmp/firefly-db.sql.gz ./
ssh giorgiocaizzi@pi.local 'rm /tmp/firefly-db.sql.gz'
```

The repo's Backrest stack handles this on schedule; manual runs above are for ad-hoc snapshots.

## 17. Disaster recovery: restore + validate

1. Restore the MariaDB dump into a fresh `firefly_db` volume.
2. Restore the `firefly_upload` volume from its archive.
3. Bring up the stack.
4. Restore OAuth keys (Personal Access Tokens stay valid only if `storage/oauth-{public,private}.key` were backed up; otherwise:):
   ```bash
   scripts/ff-artisan.sh correction:restore-oauth-keys
   scripts/ff-artisan.sh firefly-iii:laravel-passport-keys
   scripts/ff-artisan.sh cache:clear
   ```
5. Reset the Personal Access Token (UI → Profile → OAuth → Personal Access Tokens; old tokens won't work if keys were regenerated). Re-create the `firefly_access_token` Swarm secret and `docker service update --force firefly_scheduler`.
6. Repair the DB:
   ```bash
   scripts/ff-artisan.sh firefly-iii:report-integrity
   scripts/ff-artisan.sh firefly-iii:correct-database
   scripts/ff-artisan.sh firefly-iii:refresh-running-balance --force
   ```
7. Re-attach attachments:
   ```bash
   scripts/ff-artisan.sh firefly-iii:scan-attachments
   ```
8. Smoke-test:
   ```bash
   scripts/ff-api.sh GET /api/v1/about
   scripts/ff-api.sh GET /api/v1/summary/basic?start=2026-01-01&end=2026-12-31&currency_code=EUR
   ```
