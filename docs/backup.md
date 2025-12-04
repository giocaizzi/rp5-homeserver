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

## Setup

### 1. GCS Bucket (via Terraform)

GCS bucket and service account are provisioned by Terraform. See [`cloud/README.md`](../cloud/README.md).

After `terraform apply`:
```bash
terraform output -raw backup_service_account_key | base64 -d > ../infra/secrets/gcp_service_account.json
```

### 2. Configure Backrest

1. Access `https://backrest.home`
2. **Add repository**:
   - Type: Google Cloud Storage
   - Path: `gs:<bucket>:/`
   - Environment: `GOOGLE_APPLICATION_CREDENTIALS=/run/secrets/gcp_service_account`
3. **Create backup plan**:
   - Source: `/backup/docker-volumes`
   - Schedule: Daily at preferred time (e.g., 6:00 AM UTC)
   - Retention: 7 daily, 4 weekly, 6 monthly, 2 yearly

## What to Back Up

**Critical volumes** (databases, config, user data):
- All `*_db` and `*_data` volumes containing databases
- Configuration volumes (`portainer_data`, `backrest_config`, `grafana_data`)
- User uploads and attachments

**Non-critical** (can be regenerated):
- Cache volumes (`nginx_cache`, `netdata_cache`)
- Log volumes (`*_logs`)
- Metrics/traces (time-series data that ages out)

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
