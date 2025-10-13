#!/bin/bash
set -euo pipefail

# Restic Restore Script for RP5 Home Server
# Usage: ./restore.sh [snapshot-id] [restore-path] [target-path]

CONTAINER_NAME="restic_backup"

show_usage() {
    echo "Usage: $0 [OPTIONS] <restore-path> <target-path>"
    echo ""
    echo "OPTIONS:"
    echo "  -s, --snapshot ID    Snapshot ID to restore from (default: latest)"
    echo "  -l, --list          List available snapshots"
    echo "  -f, --files PATH    List files in snapshot at PATH"
    echo "  -h, --help          Show this help"
    echo ""
    echo "EXAMPLES:"
    echo "  $0 --list"
    echo "  $0 --files /backup/home/giorgiocaizzi"
    echo "  $0 /backup/home/giorgiocaizzi/Documents /tmp/restore"
    echo "  $0 --snapshot abc123 /backup/docker-volumes/n8n_postgres_data /tmp/restore-db"
    echo ""
    echo "RESTORE PATHS:"
    echo "  /backup/home/giorgiocaizzi      - User home directory"
    echo "  /backup/docker-volumes          - All Docker volumes"
    echo "  /backup/docker-volumes/VOLUME   - Specific Docker volume"
}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

error_exit() {
    log "ERROR: $1"
    exit 1
}

# Check if container exists and is running
if ! docker ps --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    error_exit "Restic container '$CONTAINER_NAME' is not running. Start infrastructure stack first."
fi

# Parse command line arguments
SNAPSHOT_ID="latest"
ACTION=""
RESTORE_PATH=""
TARGET_PATH=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--snapshot)
            SNAPSHOT_ID="$2"
            shift 2
            ;;
        -l|--list)
            ACTION="list"
            shift
            ;;
        -f|--files)
            ACTION="files"
            RESTORE_PATH="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            if [[ -z "$RESTORE_PATH" ]]; then
                RESTORE_PATH="$1"
            elif [[ -z "$TARGET_PATH" ]]; then
                TARGET_PATH="$1"
            else
                error_exit "Unknown argument: $1"
            fi
            shift
            ;;
    esac
done

# Execute actions
case "$ACTION" in
    "list")
        log "Available snapshots:"
        docker exec "$CONTAINER_NAME" restic snapshots
        ;;
    "files")
        [[ -z "$RESTORE_PATH" ]] && error_exit "Path required for --files option"
        log "Files in snapshot '$SNAPSHOT_ID' at path '$RESTORE_PATH':"
        docker exec "$CONTAINER_NAME" restic ls "$SNAPSHOT_ID" "$RESTORE_PATH"
        ;;
    *)
        # Restore operation
        [[ -z "$RESTORE_PATH" ]] && error_exit "Restore path required"
        [[ -z "$TARGET_PATH" ]] && error_exit "Target path required"

        # Create target directory on host
        TARGET_HOST_PATH="/tmp/restic-restore-$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$TARGET_HOST_PATH"

        log "Restoring from snapshot '$SNAPSHOT_ID'..."
        log "Source: $RESTORE_PATH"
        log "Target: $TARGET_HOST_PATH"

        # Mount target directory into container and restore
        docker exec "$CONTAINER_NAME" sh -c "
            mkdir -p /restore-target && 
            restic restore '$SNAPSHOT_ID' \
                --target /restore-target \
                --include '$RESTORE_PATH' \
                --verbose
        "

        # Copy restored files to host
        docker cp "$CONTAINER_NAME:/restore-target$RESTORE_PATH" "$TARGET_HOST_PATH/"

        log "Restore completed successfully"
        log "Files restored to: $TARGET_HOST_PATH"
        log "To restore to original location, manually copy files:"
        log "  sudo cp -r $TARGET_HOST_PATH/* /"
        ;;
esac