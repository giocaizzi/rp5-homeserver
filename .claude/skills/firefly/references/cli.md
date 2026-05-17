# Firefly III artisan CLI reference

Operational reference for the Laravel/artisan commands that ship inside the `fireflyiii/core` image (currently 6.6.2 on this stack). Every command runs as:

```bash
docker exec <firefly-app-container> php artisan <command> [args]
```

Use `scripts/ff-artisan.sh` from this skill — it resolves the container by Swarm label and SSHes for you. From the Pi directly: `docker exec $(docker ps -qf 'label=com.docker.swarm.service.name=firefly_app' | head -1) php artisan ...`.

> Official user-facing docs: <https://docs.firefly-iii.org/references/firefly-iii/cli/>. That page only covers `cron`, `apply-rules`, `export-data`. Everything else below is sourced from the command classes in `app/Console/Commands/*` on the deployed version's tag.

## Command surface

The signatures fall into five buckets — `firefly-iii:*` (user-facing), `correction:*` / `integrity:*` (db hygiene), `system:*` (recovery), and `firefly-iii:upgrade-database` (one-shot migrations). All commands print to stdout — capture exit code for scripting.

`php artisan` with no argument lists every command. This includes Laravel built-ins, upgrade commands, and integrity tooling.

---

## 1. Tools — daily operations

### `firefly-iii:cron`
Fires every scheduled job: process recurring transactions, run auto-budgets, refresh exchange rates, send bill reminders, recompute running balances. **Idempotent within the day.**

This is what the `firefly-scheduler` Alpine container runs nightly:
```bash
docker exec <firefly-app> php artisan firefly-iii:cron
```
On this stack it's also reachable over HTTP at `GET /api/v1/cron/{STATIC_CRON_TOKEN}` (unauthenticated, token-gated). The scheduler uses `docker exec` so this HTTP path is a backup.

**Flags:**
- `--force` — ignore the "already ran today" guard.
- `--date=YYYY-MM-DD` — pretend the run is happening on that date (useful for back-filling recurring tx the cron missed).

### `firefly-iii:apply-rules`
Bulk-replays rules against historical transactions. The API equivalent is per-rule and slower; use this for large back-fills.

```bash
php artisan firefly-iii:apply-rules \
  --user=1 \
  --token=<access_token> \
  --accounts=1,2,3 \
  --rule_groups=4 \
  --start_date=2026-01-01 \
  --end_date=2026-05-17
```

Key flags:
- `--user=USER` (default `1`) — single-user setup is always `1`.
- `--token=TOKEN` — Personal Access Token from Profile → OAuth.
- `--accounts=...` — comma-separated asset/liability IDs (omit = all).
- `--rule_groups=...` — comma-separated group IDs.
- `--rules=...` — comma-separated rule IDs. **Overrides** `rule_groups`.
- `--all_rules` — apply every rule. Overrides both.
- `--start_date=`/`--end_date=` `YYYY-MM-DD` (inclusive). Omit = full history.

Watches: a rule with `delete_transaction` action will silently nuke matched txs. `GET /rules/{id}/test` first.

### `firefly-iii:check-for-updates [--force]`
Pings the update server to check for new Firefly releases. Result is cached in DB (`last_update_check`). On this stack we update via Shepherd watching the `fireflyiii/core:latest` image, so this command's main use is dismissing the "update available" banner after Shepherd pulls.

### `firefly-iii:verify-database-connection`
Smoke test — connects to MariaDB using `.env` credentials, returns nonzero on failure. Useful before running a `correct-database` to be sure the DB is reachable.

### `firefly-iii:send-test-email`
Sends a mail through whatever `MAIL_*` env vars are configured. Current stack has `MAIL_MAILER=log` (no real mailer), so this just writes to the laravel log inside the container — confirm with `docker service logs -f firefly_app`.

---

## 2. Export

### `firefly-iii:export-data`
Dump user data to CSV/JSON files. The container writes to whatever `--export_directory` you pass — default `./` (i.e. `/var/www/html`). Most useful target on this stack: `/var/www/html/storage/upload/` which is mounted on the `firefly_upload` volume and visible to both `firefly_app` and `firefly_importer`.

```bash
ff-artisan.sh firefly-iii:export-data \
  --user=1 \
  --token=<access_token> \
  --export_directory=/var/www/html/storage/upload \
  --start=2026-01-01 \
  --end=2026-12-31 \
  --export-transactions \
  --export-accounts \
  --export-budgets \
  --export-categories \
  --export-tags \
  --export-recurring \
  --export-rules \
  --export-subscriptions \
  --export-piggies
```

Combine flags freely. `--force` overwrites any existing file with the same name. Files land as `<date>-transactions.csv`, `<date>-accounts.csv`, etc.

> The `--token` here must be a **Personal Access Token**, not the cron token. Read it from the `firefly_access_token` secret on the scheduler.

After export, retrieve from your machine:
```bash
scp giorgiocaizzi@pi.local:/var/lib/docker/volumes/firefly_firefly_upload/_data/*.csv ./
```

---

## 3. System — recovery and version

### `system:create-first-user <email>`
Creates the bootstrap admin and prints the generated password on stdout. Intended for fresh-installs and tests only — running on an existing instance creates an additional user.

### `firefly-iii:output-version`
Prints the version string (e.g. `6.6.2`). Cheaper than hitting `/api/v1/about`.

### `firefly-iii:set-latest-version [--james-is-cool]`
Stamps the DB with the current code version after a manual upgrade. The flag is required (it is, in fact, the actual flag name) — it's a sanity check to stop you running this by accident. Run after upgrading the image if Firefly throws a "please upgrade DB" error you've already resolved.

### `firefly-iii:laravel-passport-keys`
Wrapper around `passport:keys` that returns success even if the keys already exist. Use after restoring `storage/oauth-*.key` from a backup to regenerate any missing pair.

### `firefly-iii:scan-attachments`
Re-scans every attachment in storage, recomputes MD5 and mime, updates the DB. Run after restoring the `firefly_upload` volume from backup or after moving attachments between hosts.

### `firefly-iii:refresh-running-balance [-F|--force]`
Recomputes every account's running balance from the journal history. Mandatory after any direct SQL on `transactions` or `transaction_journals`. **Slow** on large histories — use `--force` if a previous run was interrupted and the cache is stuck.

### `firefly-iii:reset-error-mail-limit`
Resets the throttle on error emails (Firefly will only mail the same error once per N minutes). Run after fixing a noisy bug so the next occurrence is reported.

### `firefly-iii:verify-security-alerts`
Cross-checks the app version against the Firefly III security alert feed. The `firefly-iii:cron` job runs this implicitly; invoke directly to test connectivity.

### `system:create-database`
Bootstraps the schema on a fresh DB. The image runs this on first boot — only useful if you've created a new database manually.

### `system:forces-migrations` (`firefly-iii:force-migrations`)
Forces `migrate` to re-apply, ignoring the `migrations` table state. **Destructive.** Only used by support when an upgrade left the DB half-migrated.

### `system:forces-decimal-size`
Re-aligns DB columns to the decimal precision the code expects. Safe to re-run.

### `system:outputs-instructions`
Prints the post-install instructions (URL, register first user, OAuth, etc.) that you see at the end of `docker logs firefly-app` after boot.

---

## 4. Correction — database hygiene

These commands fix specific data anomalies. They are safe to run repeatedly; each verifies before mutating. Run them through `firefly-iii:correct-database` (which dispatches the full suite) rather than individually, except when you know exactly which fix you want.

### `firefly-iii:correct-database`
Runs *every* `correction:*` and most `integrity:*` commands in the right order. Idempotent. This is the "fix everything" hammer — invoke after:
- A restore from backup
- A manual SQL repair on `transaction_groups` / `transaction_journals` / `transactions` (see `references/db.md`)
- An upgrade that warns about integrity issues

After it finishes, clear the cache and refresh balances:
```bash
ff-artisan.sh cache:clear
ff-artisan.sh firefly-iii:correct-database
ff-artisan.sh firefly-iii:refresh-running-balance
```

### Individual `correction:*` commands

| Command | Fixes |
|---|---|
| `correction:access-tokens` | Generates per-user CLI access tokens missing from `preferences` |
| `correction:restore-oauth-keys` | Regenerates `storage/oauth-{public,private}.key` if lost (e.g. after volume reset) — fixes `401 Unauthenticated` for every API call |
| `firefly-iii:clears-empty-foreign-amounts` | Clears `foreign_amount`/`foreign_currency_id` left as zero/null inconsistently |
| `firefly-iii:converts-dates-to-utc` | One-off; converts dates stored without TZ to UTC. Run by upgrade only |
| `firefly-iii:corrects-account-order` | Re-numbers `order` column on accounts |
| `firefly-iii:corrects-account-types` | Fixes mis-typed account rows |
| `firefly-iii:corrects-amounts` | Recomputes `amount` on `transactions` from `amount_with_currency` |
| `firefly-iii:corrects-currencies` | Aligns transaction currency with the account currency |
| `firefly-iii:corrects-frontpage-accounts` | Removes deleted accounts from the dashboard preference |
| `firefly-iii:corrects-group-accounts` | Cleans up multi-user group memberships |
| `firefly-iii:corrects-group-information` | Recomputes `group_title` after splits change |
| `firefly-iii:corrects-ibans` | Strips spaces and uppercases IBAN columns |
| `firefly-iii:corrects-inverted-budget-limits` | Fixes negative budget limits inserted incorrectly |
| `firefly-iii:corrects-long-descriptions` | Truncates over-long descriptions to the column limit |
| `firefly-iii:corrects-meta-data-fields` | Removes orphaned `journal_meta` rows |
| `firefly-iii:corrects-opening-balance-currencies` | Aligns OB rows with the account currency |
| `firefly-iii:corrects-piggy-banks` | Recomputes piggy-bank totals from `piggy_bank_events` |
| `firefly-iii:corrects-preferences` | Removes preferences referencing deleted entities |
| `firefly-iii:corrects-primary-currency-amounts` | Recomputes the "primary currency" mirror columns |
| `firefly-iii:corrects-recurring-transactions` | Repairs broken recurrence definitions |
| `firefly-iii:corrects-timezone-information` | Fixes TZ on journal dates |
| `firefly-iii:corrects-transaction-types` | Reassigns `transaction_type_id` based on source/destination types |
| `firefly-iii:corrects-transfer-budgets` | Removes budgets attached to transfers (illegal combo) |
| `firefly-iii:corrects-uneven-amount` | Fixes journals where the two transaction rows don't sum to zero |
| `firefly-iii:creates-group-memberships` | Backfills `user_group` rows from `users` |
| `firefly-iii:creates-link-types` | Ensures the default 4 link types exist |
| `firefly-iii:removes-bills` | Removes bill rows that have no name/dates |
| `firefly-iii:removes-empty-groups` | Drops `transaction_groups` with zero journals |
| `firefly-iii:removes-empty-journals` | Drops `transaction_journals` with fewer than 2 `transactions` rows |
| `firefly-iii:removes-links-to-deleted-objects` | Cleans `journal_links` pointing at soft-deleted journals |
| `firefly-iii:removes-orphaned-transactions` | Drops `transactions` whose parent journal vanished |
| `firefly-iii:removes-zero-amount` | Drops `transactions` with `amount=0` (the API rejects these on store, but legacy data may have them) |
| `firefly-iii:triggers-credit-calculation` | Recomputes liability "credit" balances |
| `firefly-iii:rollback-single-migration` | Reverses one migration. **Last resort** — used to recover from a failed upgrade |

---

## 5. Integrity — reports (read-only)

Every `integrity:*` and the `firefly-iii:report-*` commands are non-destructive. They print findings and exit. Run before a `correct-database` to see what will change.

| Command | Reports |
|---|---|
| `firefly-iii:report-integrity` | Top-level overview — calls the others |
| `firefly-iii:reports-empty-objects` | Budgets/categories/bills/tags with no transactions |
| `firefly-iii:reports-sums` | Per-user money sums (sanity check against a backup) |
| `integrity:validates-environment-variables` | Warns about deprecated / typo env vars (e.g. `APP_KEY` length, missing `_FILE` paths) |
| `integrity:validates-file-permissions` | Checks `/var/www/html/storage` is writable |

---

## 6. Upgrade — version migrations

These commands run automatically when the container starts on a new version. You only invoke them manually if `firefly-iii:upgrade-database` (the umbrella) fails partway through and you need to re-run a specific step.

### `firefly-iii:upgrade-database`
Runs every `firefly-iii:upgrades-*` step in order. Replaces `migrate:fresh` for app-level schema migrations (which still run via Laravel `migrate`). Idempotent.

Individual steps (do not normally run by hand):
- `firefly-iii:adds-transaction-identifiers` — backfills the `external_id` column
- `firefly-iii:removes-database-decryption` — strips legacy encrypted columns
- `firefly-iii:repairs-account-balances`, `firefly-iii:repairs-postgres-sequences`
- `firefly-iii:upgrades-account-currencies`, `firefly-iii:upgrades-account-meta-data`
- `firefly-iii:upgrades-attachments`
- `firefly-iii:upgrades-bills-to-rules`
- `firefly-iii:upgrades-budget-limits`, `firefly-iii:upgrades-budget-limit-periods`
- `firefly-iii:upgrades-credit-card-liabilities`
- `firefly-iii:upgrades-currency-preferences`, `firefly-iii:upgrades-various-currency-information`
- `firefly-iii:upgrades-database` (top-level entry, but also callable)
- `firefly-iii:upgrades-journal-meta-data`, `firefly-iii:upgrades-journal-notes`
- `firefly-iii:upgrades-liabilities`, `firefly-iii:upgrades-liabilities-eight`
- `firefly-iii:upgrades-multi-piggy-banks`
- `firefly-iii:upgrades-primary-currency-amounts`
- `firefly-iii:upgrades-recurrence-meta-data`
- `firefly-iii:upgrades-rule-actions`
- `firefly-iii:upgrades-tag-locations`
- `firefly-iii:upgrades-to-groups`
- `firefly-iii:upgrades-transfer-currencies`
- `firefly-iii:upgrades-webhooks`

---

## 7. Laravel built-ins worth knowing

These are not `firefly-iii:*` commands but ship with Laravel. Run them inside the app container.

| Command | Use |
|---|---|
| `cache:clear` | After config or DB change |
| `config:clear` / `config:cache` | If you edit `.env` and the new value isn't read |
| `route:clear` | After upgrades that touched routes |
| `view:clear` | After UI upgrades |
| `queue:work --once` | Run one queued job (Firefly uses sync queue by default, so rarely needed) |
| `passport:keys --force` | Forcibly regenerate OAuth signing keys — invalidates existing tokens |
| `passport:client --personal` | Create a new Personal Access *Client* (one-time, after passport keys reset) |
| `passport:install` | Bootstrap Passport on a fresh install |
| `migrate` | Apply schema migrations (idempotent) |
| `tinker` | REPL on the live app (read `App\Models\...` to inspect) |

---

## 8. Typical command sequences

**Nightly cron (what the scheduler runs):**
```bash
ff-artisan.sh firefly-iii:cron
```

**Recover from a database restore:**
```bash
ff-artisan.sh cache:clear
ff-artisan.sh firefly-iii:report-integrity     # see what's broken
ff-artisan.sh firefly-iii:correct-database     # fix it
ff-artisan.sh firefly-iii:refresh-running-balance --force
```

**Recover from a lost `storage/oauth-*.key`:**
```bash
ff-artisan.sh correction:restore-oauth-keys
ff-artisan.sh firefly-iii:laravel-passport-keys
ff-artisan.sh cache:clear
```
All existing Personal Access Tokens **stay valid** — they're signed with the same restored key pair.

**Full export of every user object:**
```bash
ff-artisan.sh firefly-iii:export-data \
  --token=$(ssh giorgiocaizzi@pi.local 'docker exec $(docker ps -qf label=com.docker.swarm.service.name=firefly_scheduler | head -1) cat /run/secrets/firefly_access_token') \
  --export_directory=/var/www/html/storage/upload \
  --export-transactions --export-accounts --export-budgets \
  --export-categories --export-tags --export-recurring \
  --export-rules --export-subscriptions --export-piggies \
  --force
```

**Bulk-apply all rules to last quarter:**
```bash
ff-artisan.sh firefly-iii:apply-rules \
  --token=<...> \
  --all_rules \
  --start_date=2026-02-01 \
  --end_date=2026-04-30
```
