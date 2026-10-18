# Backup

Backrest (restic with web UI) backs up Docker volumes to Google Cloud Storage.

**Web UI**: `https://backrest.home`

## How It Works

Backrest mounts `/var/lib/docker/volumes` read-only and creates incremental snapshots to GCS.

| Component | Description |
|-----------|-------------|
| **Backend** | Restic with GCS storage |
| **Retention** | Configurable (default: 7 daily, 4 weekly, 6 monthly, 2 yearly) |
| **Schedule** | Configured per backup plan in Web UI |

## Database Dumps

Copying a running database's files does not give a consistent copy, so the raw `*_db`/`*_data` volumes are only a second copy. The restorable backup is a logical dump taken just before each `docker-volumes` snapshot:

1. A Backrest command hook (`CONDITION_SNAPSHOT_START`, `ON_ERROR_FATAL`) runs [`infra/backrest/dump-dbs.sh`](../infra/backrest/dump-dbs.sh).
2. The script `docker exec`s the engine's own dump tool in each DB task, with that container's credentials, and writes to the `infra_backrest_dumps` volume (`/dumps`). Backrest never holds a DB password.
3. The snapshot then picks the dumps up under `/backup/docker-volumes/infra_backrest_dumps/_data/`. Restic keeps the history; the volume holds only the latest dump.
4. If any dump fails, the snapshot fails and the error hook alerts ntfy (topic `backup`). `ON_ERROR_CANCEL` would stop the snapshot silently, without running error hooks.

| File | Source | Tool |
|------|--------|------|
| `firefly.sql` | `firefly_db` (MariaDB) | `mariadb-dump --single-transaction` |
| `crm.sql` | `crm_db` (Postgres) | `pg_dump` |
| `n8n.sql` | `n8n_db` (Postgres) | `pg_dump` |
| `greenhouse.db` | `greenhouse_app` (SQLite) | Python `sqlite3` online backup |

Backrest reaches Docker only through `infra_docker-proxy` ([wollomatic/socket-proxy](https://github.com/wollomatic/socket-proxy)). Its allowlist permits listing containers, exec into these four tasks and the prune endpoints used by the janitor ([disk hygiene](./monitoring.md#disk-hygiene)), nothing else: no container create, no exec into other containers. Adding a database means adding a `dump` line to the script and its service name to both proxy allowlist regexes in `infra/docker-compose.yml`.

Restore: [RUNBOOKS/restore-database.md](./RUNBOOKS/restore-database.md).

## Setup

### 1. GCS Bucket (via Terraform)

GCS bucket and service account are provisioned by Terraform. See [`cloud/README.md`](../cloud/README.md).

After `terraform apply`:
```bash
bws secret create infra_gcp_service_account "$(terraform output -raw backup_service_account_key | base64 -d)" <project-id>   # then sync_infra.sh
```

### 2. Configure Backrest

1. Access `https://backrest.home`
2. **Add repository**:
   - Type: Google Cloud Storage
   - Path: `gs:<bucket>:/`
   - Environment: `GOOGLE_APPLICATION_CREDENTIALS=/run/secrets/gcp_service_account`
3. **Create backup plan**:
   - Source: `/backup/docker-volumes`
   - Excludes (recommended):
     - `/backup/docker-volumes/*ollama_data*` (skip Ollama models)
   - Schedule: Daily at preferred time (e.g., 6:00 AM UTC)
   - Retention: 7 daily, 4 weekly, 6 monthly, 2 yearly
4. **Add hooks to the `docker-volumes` plan** (plan → Hooks):
   - Command, condition `CONDITION_SNAPSHOT_START`, on error `ON_ERROR_FATAL`, command `bash /scripts/dump-dbs.sh`
   - Command, condition `CONDITION_ANY_ERROR`, on error `ON_ERROR_IGNORE`, command:
     ```bash
     curl -fsS -H "Authorization: Bearer $(cat /run/secrets/ntfy_token)" -H "Title: Backrest error" --data-binary @- http://ntfy_app/backup <<'EOF'
     {{ .Summary }}
     EOF
     ```

## What to Back Up

**Critical data** (databases, config, user data):
- Database dumps in `infra_backrest_dumps` (see [Database Dumps](#database-dumps)); the raw `*_db` and `*_data` volumes stay as a second copy
- Configuration volumes (`portainer_data`, `backrest_config`, `grafana_data`)
- User uploads and attachments

**Non-critical** (can be regenerated):
- Cache volumes (`nginx_cache`, `netdata_cache`)
- Log volumes (`*_logs`)
- Metrics/traces (time-series data that ages out)
- Ollama model data (`*ollama_data*`) when model re-pull is acceptable

Each service README documents its volumes under **💾 Volumes**.

## Restore

### Via Web UI

1. `https://backrest.home` → Snapshots
2. Browse snapshot contents
3. Select files → Restore

### Via CLI

```bash
# List snapshots
docker exec backrest restic -r /data/repos/<repo> snapshots

# Restore specific path
docker exec backrest restic -r /data/repos/<repo> restore latest \
  --target /restore --include <path>
```

## Verification

```bash
# Check repository integrity
docker exec backrest restic -r /data/repos/<repo> check

# Repository stats
docker exec backrest restic -r /data/repos/<repo> stats latest
```
