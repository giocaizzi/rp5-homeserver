# Backup System

Docker-based Backrest (restic with web UI) integrated into infrastructure stack. Backs up user data and Docker volumes to Google Cloud Storage.

## Architecture

**Backup Targets:**
- `/home/giorgiocaizzi` - User home directory
- `/var/lib/docker/volumes` - All Docker volumes (n8n, ollama, portainer data)

**Storage:** Google Cloud Storage bucket with incremental snapshots

**Retention Policy (configured in Web UI):**
- Daily: 7 snapshots
- Weekly: 4 snapshots  
- Monthly: 6 snapshots
- Yearly: 2 snapshots

**Web UI:** https://backrest.local (accessible after setup)

## Setup

### 1. Google Cloud Storage

**Create bucket:**
```bash
gsutil mb gs://your-backup-bucket-name
```

**Create service account:**
```bash
gcloud iam service-accounts create restic-backup \
  --description="Restic backup service account" \
  --display-name="Restic Backup"

gcloud projects add-iam-policy-binding YOUR-PROJECT-ID \
  --member="serviceAccount:restic-backup@YOUR-PROJECT-ID.iam.gserviceaccount.com" \
  --role="roles/storage.objectAdmin"

gcloud iam service-accounts keys create gcp_service_account.json \
  --iam-account=restic-backup@YOUR-PROJECT-ID.iam.gserviceaccount.com
```

### 2. Configure Secrets

**Create GCP service account key file:**
```bash
cd infra/backup/secrets

# Download JSON key from Google Cloud Console and save as:
# gcp_service_account.json
```

**Update environment:**
```bash
# In infra/.env
GCP_SERVICE_ACCOUNT_FILE=./backup/secrets/gcp_service_account.json
```

### 3. Deploy Stack

```bash
cd infra
docker compose up -d
```

### 4. Configure Backrest via Web UI

1. Access web UI at https://backrest.local
2. Create a new repository:
   - Name: `rp5-homeserver`
   - Type: `Google Cloud Storage`
   - Path: `gs://<GCS_BUCKET_NAME>/backups/rp5-homeserver`
   - Password: Strong repository password (save this securely)
   - Environment variables:
     - `GOOGLE_APPLICATION_CREDENTIALS=/gcp/credentials.json`
     - `GOOGLE_PROJECT_ID=your-gcp-project-id`
3. Create backup plans:
   - **User Home Backup**:
     - Paths: `/backup/home/giorgiocaizzi`
     - Schedule: Daily at 2 AM
     - Retention: Keep last 7 daily, 4 weekly, 6 monthly, 2 yearly
   - **Docker Volumes Backup**:
     - Paths: `/backup/docker-volumes`
     - Schedule: Daily at 3 AM
     - Retention: Keep last 7 daily, 4 weekly, 6 monthly, 2 yearly

## Usage

### Automated Backup
Backups are scheduled via the Backrest web UI. No cron setup required.

### Manual Backup
Trigger backups manually via the web UI:
1. Navigate to https://backrest.local
2. Select backup plan
3. Click "Backup Now"

### Restore Operations

**Via Web UI (Recommended):**
1. Navigate to https://backrest.local
2. Go to "Snapshots" tab
3. Browse snapshot contents
4. Select files/folders to restore
5. Choose restore location
6. Execute restore

**Via CLI (Advanced):**
Access the container directly for restic commands:
```bash
# List snapshots
docker exec backrest restic -r /data/repos/rp5-homeserver snapshots

# Browse files
docker exec backrest restic -r /data/repos/rp5-homeserver ls latest /backup/home/giorgiocaizzi

# Restore specific directory
docker exec backrest restic -r /data/repos/rp5-homeserver restore latest \
  --target /restore --include /backup/home/giorgiocaizzi/Documents
```

## Monitoring

**Web UI Dashboard:**
- Access https://backrest.local
- View backup status, last run times, and errors
- Check repository size and snapshot counts
- Monitor backup plan execution history

**Container logs:**
```bash
docker logs -f backrest
```

**Repository status (via CLI):**
```bash
docker exec backrest restic -r /data/repos/rp5-homeserver snapshots
docker exec backrest restic -r /data/repos/rp5-homeserver stats latest
```

**Check repository integrity:**
```bash
docker exec backrest restic -r /data/repos/rp5-homeserver check
```

## Security

- Repository encrypted with strong password
- GCP service account with minimal permissions
- Secrets managed via Docker secrets (not environment variables)
- Read-only access to backup sources

## Performance

- **Cache volume** for faster operations
- **Incremental backups** reduce transfer size
- **Resource limits** prevent system impact during backup
- **Monthly integrity checks** ensure repository health

## Troubleshooting

**Container not running:**
```bash
# Check container status
docker ps | grep backrest

# Ensure infrastructure stack is running
cd ~/rp5-homeserver/infra && docker compose up -d
```

**Web UI not accessible:**
```bash
# Check if service is listening
docker exec backrest wget -qO- http://localhost:9898/

# Check nginx proxy
docker logs nginx | grep backrest

# Verify hosts file
cat /etc/hosts | grep backrest.local
```

**GCS authentication issues:**
```bash
# Verify credentials file
docker exec backrest ls -la /gcp/credentials.json

# Test GCS access
docker exec backrest env GOOGLE_APPLICATION_CREDENTIALS=/gcp/credentials.json \
  gsutil ls gs://<GCS_BUCKET_NAME>
```

**Repository issues:**
```bash
# Check repository in web UI under "Repositories" tab
# Or repair via CLI:
docker exec backrest restic -r /data/repos/rp5-homeserver rebuild-index
docker exec backrest restic -r /data/repos/rp5-homeserver prune
```

**Backup failures:**
1. Check web UI notifications
2. Review backup plan logs in web UI
3. Check container logs: `docker logs backrest`
4. Verify backup paths are accessible in container