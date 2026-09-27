# 🤝 CRM (Twenty)

> Self-hosted [Twenty](https://github.com/twentyhq/twenty) CRM — sales pipeline UI, REST/GraphQL API for Ticky, native MCP endpoint for Claude.

**URL**: `https://crm.giocaizzi.xyz` · **Production instance** — dev/test environments must never write to it.

---

## 🚀 Quick Start

1. Create the Swarm secrets (see [Secrets](#-secrets)).
2. Deploy via Portainer → Swarm mode (Remote Stack from this repo, stack name `crm`, GitOps **Webhook**).
3. Wait for first-boot migrations (`docker service logs -f crm_server`), then open `https://crm.giocaizzi.xyz`, create the owner account + workspace.
4. Invite sales users from Settings → Members (they also need to be in the `CRM_USERS` CF Access list).
5. Create API keys in Settings → APIs & Webhooks (one per consumer: Ticky backend, MCP connector).

---

## 📦 Architecture

| Container | Image | Purpose |
|-----------|-------|---------|
| crm-server | `twentycrm/twenty:v2.43.0` | UI + REST/GraphQL/MCP API, runs DB migrations and registers cron jobs on start |
| crm-worker | `twentycrm/twenty:v2.43.0` | BullMQ background jobs (webhooks, workflows, imports, timeline) |
| crm-db | `postgres:16-alpine` | Primary data store |
| crm-redis | `redis:7-alpine` | Queue + cache (`noeviction`, no persistence) |

Worker and Redis are mandatory: the queue driver is hardcoded to BullMQ upstream.

```
Cloudflare Access ─► nginx ─► crm-server ─┬─► crm-db
                                          └─► crm-redis ◄─ crm-worker
```

**Public endpoints** (all behind Cloudflare Access):

| Path | Gate |
|------|------|
| `/` (UI) | CF Access email allowlist (`CRM_USERS`) + Twenty login |
| `/rest`, `/graphql` | CF Access service token `ticky-crm-api` + Twenty API key (Bearer) |
| `/mcp` | CF Access service token `claude-crm-mcp` (injected by `workers/mcp-connector`) + Twenty API key (Bearer) |

**Pi tuning:** memory limits server 1G / worker 1G / db 256M / redis 64M (~2.3G cap; Node heaps 768M each), Node heaps capped via `NODE_OPTIONS`, `PG_POOL_MAX_CONNECTIONS=5`, telemetry off. First boot (DB init + upgrade) is the memory peak — if `crm_server` is OOM-killed there, temporarily raise its limit.

---

## 🔐 Secrets

Twenty has no `*_FILE` support; the compose entrypoint wrapper exports `PG_DATABASE_URL` and `ENCRYPTION_KEY` from the Swarm secrets, then runs the original `/app/entrypoint.sh`.

| Secret | Generate |
|--------|----------|
| `crm_postgres_password` | `openssl rand -hex 32 > services/crm/secrets/postgres_password.txt` |
| `crm_encryption_key` | `openssl rand -base64 32 > services/crm/secrets/encryption_key.txt` |

```bash
PI_SSH_USER=<user> ./scripts/create_secrets.sh crm
```

> ⚠️ `crm_encryption_key` encrypts stored credentials (OAuth tokens, app variables, TOTP). Losing it makes them unrecoverable — keep a copy in the password manager. Postgres password is hex because it is interpolated into a URL.

---

## ⚙️ Configuration

- `SERVER_URL` is fixed to `https://crm.giocaizzi.xyz` — links and OAuth callbacks are built from it.
- Email/calendar sync and SSO are off (defaults). AI provider keys, if ever needed, go in the Twenty admin panel, not env.
- Upgrades: bump the image tag for both `server` and `worker`; the server runs `upgrade` on start.

---

## 💾 Volumes

| Volume | Purpose | Backup |
|--------|---------|--------|
| `crm_postgres_data` | Postgres data | ✅ Critical |
| `crm_storage_data` | Uploaded files/attachments (local storage) | ✅ Critical |

Backed up by Backrest (restic, encrypted) with the rest of `/var/lib/docker/volumes`. Holds B2B personal data (GDPR) — backups must stay encrypted.

**Migration set** (e.g. to a GCP VM): `pg_dump` + `crm_storage_data` + `crm_encryption_key`.

```bash
docker exec $(docker ps -qf name=crm_db) pg_dump -U twenty -Fc twenty > crm-$(date +%F).dump
```
