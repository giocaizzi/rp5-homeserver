---
name: firefly
description: End-to-end runbook for operating this Firefly III stack (personal finance manager deployed on the Pi). Use whenever the user asks about money, accounts, transactions, budgets, categories, tags, bills/subscriptions, piggy banks, recurring transactions, rules/rule-groups, reports, currencies, exchange rates, webhooks, attachments, imports (CSV, Lunch Flow, Spectre, Nordigen/GoCardless), exports, OAuth/Personal Access Tokens, integrity checks, DB rollbacks, or the firefly cron — even when they don't say "firefly". Covers the REST API (`/api/v1/*`), the artisan CLI (`php artisan firefly-iii:*`), the MariaDB schema, and the Data Importer.
---

# Firefly III runbook

Firefly III is a self-hosted personal finance manager. This skill covers running, scripting, and repairing the instance deployed in `services/firefly/`.

## Stack at a glance

| Piece | Where |
|---|---|
| App | service `firefly_app`, container `firefly-app`, internal `http://firefly-app:8080` |
| Database | service `firefly_db`, container `firefly-db`, MariaDB, DB `firefly`, user `firefly` |
| Data Importer | service `firefly_importer`, container `firefly-importer`, internal `http://firefly-importer:8080` |
| Scheduler | service `firefly_scheduler`, holds the `firefly_access_token` secret used by cron |
| Public URL | `https://firefly.giocaizzi.xyz` (also `https://firefly.home` on LAN) |
| Importer URL | `https://firefly-importer.home` |

Secrets live as external Swarm secrets (`firefly_*`). The app uses `_FILE` env vars; the importer uses the `load-secrets.sh` shim wrapped into the entrypoint. The Personal Access Token (long JWT) is in the `firefly_access_token` secret and is the credential for all CLI/API automation.

**For secret rotation, deployment, volume layout, and initial setup, defer to `services/firefly/README.md`** — that is the operator's runbook. This skill covers what to do *with* a working Firefly instance, not how to stand one up or rotate its credentials.

## How to drive Firefly

Three surfaces. Pick the one that matches the task:

1. **REST API** (`/api/v1/*`, JSON-only) — best for CRUD on transactions/accounts/budgets/etc., reports, search, and webhooks. Authenticated with a Personal Access Token sent as `Authorization: Bearer <token>`. See `references/api.md`.

2. **Artisan CLI** (`php artisan firefly-iii:*` inside the app container) — best for cron, bulk operations across users, exports, integrity checks, OAuth key recovery. See `references/cli.md`.

3. **Direct SQL** (MariaDB inside the db container) — last resort, only when API/CLI cannot recover. The schema has soft-delete semantics that must be respected. See `references/db.md`.

Prefer API → CLI → SQL, in that order. Anything that mutates state via SQL must be followed by `php artisan firefly-iii:correct-database` and a cache flush (see `references/db.md`).

## Helper scripts

Two thin wrappers in this skill's `scripts/` folder remove the SSH + secret-reading boilerplate:

- **`scripts/ff-api.sh`** — runs an authenticated curl against the app container. SSHes to the Pi, reads the token from the scheduler container's mounted secret, then `docker exec`s curl inside the app container. Usage:
  ```bash
  scripts/ff-api.sh GET  /api/v1/about
  scripts/ff-api.sh GET  /api/v1/accounts?type=asset
  scripts/ff-api.sh POST /api/v1/transactions @/path/to/payload.json
  ```
  No tokens leave the Pi. The body argument can be inline JSON, `@file.json`, or `-` for stdin.

- **`scripts/ff-artisan.sh`** — runs `php artisan` inside the app container. Usage:
  ```bash
  scripts/ff-artisan.sh firefly-iii:cron
  scripts/ff-artisan.sh firefly-iii:correct-database
  scripts/ff-artisan.sh firefly-iii:report-integrity
  scripts/ff-artisan.sh firefly-iii:export-data --token=... --export-transactions
  ```

Both scripts honour `PI_SSH_USER` (default `giorgiocaizzi`) and `PI_HOST` (default `pi.local`), matching the convention used by `scripts/` at the repo root.

## When to read which reference

| Task | Read |
|---|---|
| Any HTTP call against Firefly (CRUD, charts, insight, summary, search, webhooks, attachments) | `references/api.md` |
| Running cron, applying rules in bulk, exporting data, integrity reports, OAuth recovery, user mgmt | `references/cli.md` |
| End-to-end recipes (create accounts → ingest CSV → tag → budget → reconcile → report) | `references/workflows.md` |
| Soft-deletes, restoring transactions, fixing orphaned rows, schema cheat-sheet | `references/db.md` |
| Lunch Flow / Spectre / GoCardless / CSV import via the Data Importer container, autoimport endpoint, config rotation | `references/importer.md` |

## Operating rules

- **Never log or echo the access token.** Read it inside the container (`cat /run/secrets/firefly_access_token`), pipe it into the request, do not capture it to local files.
- **Read before writing.** For any destructive action (DELETE, `php artisan firefly-iii:correct-database`, SQL update), first `GET` the affected resource and confirm the IDs.
- **The API URL is internal.** From outside the Pi, prefer `ff-api.sh` over hitting `https://firefly.giocaizzi.xyz` directly so the request stays on the overlay network and the token never crosses the public internet.
- **Idempotency.** Set `error_if_duplicate_hash: true` on every transaction store to make replays safe; Firefly hashes the journal and rejects exact dupes with `422`.
- **Rule fire-and-forget.** When creating/updating transactions, the default is `apply_rules: true, fire_webhooks: true`. Set to `false` for bulk migrations to avoid storms.
- **Currency.** All amounts are decimal strings (`"12.34"`), never numbers. Mixing types silently rounds.
- **Dates.** Firefly accepts both `YYYY-MM-DD` and full ISO-8601. Use ISO-8601 with explicit offset when timezone matters (e.g., recurring transactions stored UTC but displayed `Europe/Rome`).
- **Pagination defaults.** Index endpoints return 50 items per page. Pass `?limit=N&page=N` and read `meta.pagination` to walk the rest. Maximum is 100 per page on most endpoints.

## Common failure modes (quick lookup)

| Symptom | Likely cause | Read |
|---|---|---|
| `401 Unauthenticated` | Token expired or wrong, or OAuth keys missing after restore | `references/cli.md` (`correction:restore-oauth-keys`) |
| `422 Validation` with `transactions.0.amount` | Sent number instead of string, or missing `source_id`/`destination_id` | `references/api.md` (transaction shape) |
| `422` with `a115` "duplicate hash" | Already imported — usually benign in importer logs | `references/importer.md` |
| Running balance wrong after restore | Need to refresh balances | `references/db.md` |
| Transactions vanished after manual SQL | Parent group/journal still soft-deleted; Firefly cascades | `references/db.md` (rollback pattern) |
| Cron never fires | `STATIC_CRON_TOKEN` mismatch or scheduler container down | `references/cli.md` (`firefly-iii:cron`) |
| Importer hangs after config swap | Swarm config lock — must detach/reattach | `references/importer.md` |
