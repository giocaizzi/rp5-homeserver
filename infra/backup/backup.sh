#!/bin/bash
set -euo pipefail

# Restic Backup Script for RP5 Home Server
# This script performs incremental backups to Google Cloud Storage
# 
# USAGE:
#   Manual: ./backup.sh
#   Automated: Run from Pi cron (recommended)
#     sudo crontab -e
#     0 2 * * * cd /home/pi/rp5-homeserver/infra && ./backup/backup.sh >> /var/log/restic-backup.log 2>&1

CONTAINER_NAME="restic_backup"
LOG_FILE="/tmp/restic-backup-$(date +%Y%m%d-%H%M%S).log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

error_exit() {
    log "ERROR: $1"
    exit 1
}

# Check if container exists and is running
if ! docker ps --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    error_exit "Restic container '$CONTAINER_NAME' is not running. Start infrastructure stack first."
fi

log "Starting backup process..."

# Initialize repository if it doesn't exist
log "Checking repository initialization..."
if ! docker exec "$CONTAINER_NAME" restic snapshots >/dev/null 2>&1; then
    log "Initializing new restic repository..."
    docker exec "$CONTAINER_NAME" restic init || error_exit "Failed to initialize repository"
    log "Repository initialized successfully"
fi

# Perform backup
log "Creating backup snapshot..."
docker exec "$CONTAINER_NAME" restic backup \
    /backup/home/giorgiocaizzi \
    /backup/docker-volumes \
    --verbose \
    --tag "daily" \
    --tag "$(date +%Y-%m-%d)" \
    || error_exit "Backup failed"

log "Backup completed successfully"

# Apply retention policy
log "Applying retention policy..."
docker exec "$CONTAINER_NAME" restic forget \
    --keep-daily 7 \
    --keep-weekly 4 \
    --keep-monthly 6 \
    --keep-yearly 2 \
    --prune \
    --verbose \
    || log "WARNING: Retention policy application failed"

# Check repository integrity (monthly on 1st day)
if [ "$(date +%d)" == "01" ]; then
    log "Performing monthly repository check..."
    docker exec "$CONTAINER_NAME" restic check \
        --verbose \
        || log "WARNING: Repository check failed"
fi

# Display backup statistics
log "Backup statistics:"
docker exec "$CONTAINER_NAME" restic stats latest \
    || log "WARNING: Could not retrieve backup statistics"

log "Backup process completed. Log saved to: $LOG_FILE"