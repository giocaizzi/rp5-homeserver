# Backup System

Docker-based Restic backup integrated into infrastructure stack. Backs up user data and Docker volumes to Google Cloud Storage.

## Architecture

**Backup Targets:**
- `/home/giorgiocaizzi` - User home directory
- `/var/lib/docker/volumes` - All Docker volumes (n8n, ollama, portainer data)

**Storage:** Google Cloud Storage bucket with incremental snapshots

**Retention Policy:**
- Daily: 7 snapshots
- Weekly: 4 snapshots  
- Monthly: 6 snapshots
- Yearly: 2 snapshots

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

**Create secrets files:**
```bash
cd infra/backup/secrets

# Create restic repository password
echo "your-strong-restic-password-here" > restic_password.txt

# Create GCP service account key file
# Download JSON key from Google Cloud Console and save as:
# gcp_service_account.json
```

**Update environment:**
```bash
# In infra/.env
GCS_BUCKET_NAME=your-backup-bucket-name
```

### 3. Deploy Stack

```bash
cd infra
docker compose up -d
```

## Usage

### Automated Backup (Recommended)
Set up cron on the Pi for automatic daily backups:

```bash
# SSH to Pi and edit crontab
ssh pi@pi.local
sudo crontab -e

# Add daily backup at 2 AM
0 2 * * * cd /home/pi/rp5-homeserver/infra && ./backup/backup.sh >> /var/log/restic-backup.log 2>&1
```

**Alternative schedules:**
```bash
# Weekly backup on Sunday at 3 AM
0 3 * * 0 cd /home/pi/rp5-homeserver/infra && ./backup/backup.sh >> /var/log/restic-backup.log 2>&1

# Twice daily (2 AM and 2 PM)
0 2,14 * * * cd /home/pi/rp5-homeserver/infra && ./backup/backup.sh >> /var/log/restic-backup.log 2>&1
```

### Manual Backup
For testing or one-off backups:
```bash
ssh pi@pi.local "cd ~/rp5-homeserver/infra && ./backup/backup.sh"
```

### Restore Operations

**List snapshots:**
```bash
ssh pi@pi.local "cd ~/rp5-homeserver/infra && ./backup/restore.sh --list"
```

**Browse files in snapshot:**
```bash
ssh pi@pi.local "cd ~/rp5-homeserver/infra && ./backup/restore.sh --files /backup/home/giorgiocaizzi"
```

**Restore specific directory:**
```bash
ssh pi@pi.local "cd ~/rp5-homeserver/infra && ./backup/restore.sh /backup/home/giorgiocaizzi/Documents /tmp/restore-docs"
```

**Restore Docker volume:**
```bash
ssh pi@pi.local "cd ~/rp5-homeserver/infra && ./backup/restore.sh /backup/docker-volumes/n8n_postgres_data /tmp/restore-db"
```

## Monitoring

**Check cron status:**
```bash
ssh pi@pi.local "sudo crontab -l"                    # List scheduled jobs
ssh pi@pi.local "sudo systemctl status cron"         # Check cron service
```

**Backup logs:**
```bash
ssh pi@pi.local "tail -f /var/log/restic-backup.log" # Follow backup logs
ssh pi@pi.local "grep ERROR /var/log/restic-backup.log" # Check for errors
```

**Repository status:**
```bash
ssh pi@pi.local "cd ~/rp5-homeserver/infra && docker exec restic_backup restic snapshots"
ssh pi@pi.local "cd ~/rp5-homeserver/infra && docker exec restic_backup restic stats latest"
```

**Check repository integrity:**
```bash
ssh pi@pi.local "cd ~/rp5-homeserver/infra && docker exec restic_backup restic check"
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

**Check if cron is running:**
```bash
ssh pi@pi.local "sudo systemctl status cron"
ssh pi@pi.local "ps aux | grep cron"
```

**Container not found:**
```bash
# Ensure infrastructure stack is running
ssh pi@pi.local "cd ~/rp5-homeserver/infra && docker compose up -d"
```

**Permission denied:**
```bash
# Check file permissions on Pi
ssh pi@pi.local "ls -la ~/rp5-homeserver/infra/backup/"
# Should be executable: backup.sh, restore.sh
```

**GCS authentication:**
```bash
# Test service account
ssh pi@pi.local "cd ~/rp5-homeserver/infra && docker exec restic_backup env | grep GOOGLE"
```

**Repository corruption:**
```bash
# Repair repository
ssh pi@pi.local "cd ~/rp5-homeserver/infra && docker exec restic_backup restic rebuild-index"
ssh pi@pi.local "cd ~/rp5-homeserver/infra && docker exec restic_backup restic prune"
```

**Backup not running automatically:**
```bash
# Check cron logs
ssh pi@pi.local "grep CRON /var/log/syslog | tail -10"
ssh pi@pi.local "tail /var/log/restic-backup.log"

# Test manual execution
ssh pi@pi.local "cd ~/rp5-homeserver/infra && ./backup/backup.sh"
```