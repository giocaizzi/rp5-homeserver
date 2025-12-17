#!/bin/bash

# Sync and deploy infra stack on Raspberry Pi using Docker Swarm
# Usage: PI_SSH_USER=username ./sync_infra.sh [options]
#
# Required environment variables:
#   PI_SSH_USER - SSH username for the Pi
#
# Optional environment variables:
#   PI_HOST - Pi hostname or IP (default: pi.local)
#   PI_INFRA_PATH - Remote infra directory path

set -euo pipefail

# Global configuration
PI_HOST="${PI_HOST:-pi.local}"
PI_INFRA_PATH=""
LOCAL_INFRA_PATH="$(cd "$(dirname "$0")/../infra" && pwd)"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Feature flags
DRY_RUN=false
PULL_IMAGES=false
FULL_RESTART=false

# Counters
FILES_SYNCED=0
FILES_DELETED=0
SERVICES_TOTAL=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
DIM='\033[2m'
NC='\033[0m'

# Logging (uniform with create_secrets.sh)
log_info()    { echo -e "${BLUE}│${NC} $1"; }
log_success() { echo -e "${BLUE}│${NC} ${GREEN}✓${NC} $1"; }
log_warning() { echo -e "${BLUE}│${NC} ${YELLOW}⚠${NC} $1"; }
log_error()   { echo -e "${BLUE}│${NC} ${RED}✗${NC} $1"; }
log_skip()    { echo -e "${BLUE}│${NC} ${DIM}─${NC} $1"; }
log_section() { echo -e "${BLUE}├─${NC} ${CYAN}$1${NC}"; }
log_end()     { echo -e "${BLUE}└─${NC} $1"; }

show_help() {
    cat << EOF
Sync and deploy infra stack on Raspberry Pi using Docker Swarm

Usage: PI_SSH_USER=username $0 [options]

Required environment variables:
  PI_SSH_USER     SSH username for the Pi

Optional environment variables:
  PI_HOST         Pi hostname or IP (default: pi.local)
  PI_INFRA_PATH   Remote infra directory path

Options:
  --dry-run       Show what would be done without executing
  --pull          Pull latest Docker images before deploying
  --restart       Full stack restart (removes and redeploys)
                  Default behavior updates in-place via docker stack deploy
  --help, -h      Show this help message

Behavior:
  Default:        Syncs files and runs 'docker stack deploy' which:
                  - Updates changed services in-place
                  - Preserves running services with no changes
                  - Zero downtime for unchanged services
                  - Always preserves named volumes
  
  --restart:      Full restart cycle:
                  - Removes entire stack (preserves named volumes)
                  - Waits for complete removal
                  - Redeploys fresh stack

Examples:
  PI_SSH_USER=pi $0                    # Sync and update in-place
  PI_SSH_USER=pi $0 --dry-run          # Preview changes
  PI_SSH_USER=pi $0 --pull             # Update with latest images
  PI_SSH_USER=pi $0 --restart          # Full stack restart
EOF
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --pull)
                PULL_IMAGES=true
                shift
                ;;
            --restart)
                FULL_RESTART=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}" >&2
                show_help
                exit 1
                ;;
        esac
    done
}

validate_environment() {
    if [ -z "${PI_SSH_USER:-}" ]; then
        echo -e "${RED}Error: PI_SSH_USER environment variable required${NC}" >&2
        exit 1
    fi
    
    PI_INFRA_PATH="${PI_INFRA_PATH:-/home/${PI_SSH_USER}/rp5-homeserver/infra}"
    
    if [ ! -d "$LOCAL_INFRA_PATH" ]; then
        echo -e "${RED}Error: Local infra directory not found: $LOCAL_INFRA_PATH${NC}" >&2
        exit 1
    fi
}

test_ssh_connection() {
    if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "$PI_SSH_USER@$PI_HOST" "true" 2>/dev/null; then
        echo -e "${RED}Error: Cannot connect to $PI_SSH_USER@$PI_HOST${NC}" >&2
        exit 1
    fi
}

get_local_version() {
    if [ -f "$LOCAL_INFRA_PATH/VERSION" ]; then
        cat "$LOCAL_INFRA_PATH/VERSION"
    else
        echo "unknown"
    fi
}

get_remote_version() {
    ssh "$PI_SSH_USER@$PI_HOST" "cat $PI_INFRA_PATH/VERSION 2>/dev/null" || echo "not deployed"
}

# Check if swarm is initialized
check_swarm() {
    local state
    state=$(ssh "$PI_SSH_USER@$PI_HOST" "docker info --format '{{.Swarm.LocalNodeState}}'" 2>/dev/null || echo "inactive")
    echo "$state"
}

# Initialize swarm if needed
initialize_swarm() {
    local state
    state=$(check_swarm)
    
    if [ "$state" = "active" ]; then
        log_skip "Swarm already active"
        return 0
    fi
    
    if [ "$DRY_RUN" = true ]; then
        log_info "Would initialize Docker Swarm"
        return 0
    fi
    
    if ssh "$PI_SSH_USER@$PI_HOST" "docker swarm init" 2>/dev/null; then
        log_success "Docker Swarm initialized"
    else
        log_error "Failed to initialize Swarm"
        return 1
    fi
}

# Sync files using rsync
sync_files() {
    log_section "Syncing files"
    
    # Ensure remote directory exists
    if [ "$DRY_RUN" = true ]; then
        log_info "Would ensure remote directory: $PI_INFRA_PATH"
    else
        ssh "$PI_SSH_USER@$PI_HOST" "mkdir -p $PI_INFRA_PATH" 2>/dev/null
    fi
    
    # Get rsync dry-run output to count changes
    local rsync_output
    rsync_output=$(rsync -avz --delete --exclude='homepage/logs/' --dry-run "$LOCAL_INFRA_PATH/" "$PI_SSH_USER@$PI_HOST:$PI_INFRA_PATH/" 2>/dev/null | grep -E '^[<>ch.]|deleting' || true)
    
    if [ -z "$rsync_output" ]; then
        log_skip "No file changes detected"
        return 0
    fi
    
    # Count changes - handle grep returning 1 when no matches
    local send_count del_count
    send_count=$(echo "$rsync_output" | grep -cvE '^deleting|^$' 2>/dev/null) || send_count=0
    del_count=$(echo "$rsync_output" | grep -c '^deleting' 2>/dev/null) || del_count=0
    
    # Ensure numeric values
    send_count=$((send_count + 0))
    del_count=$((del_count + 0))
    
    FILES_SYNCED=$send_count
    FILES_DELETED=$del_count
    
    if [ "$DRY_RUN" = true ]; then
        [ "$send_count" -gt 0 ] && log_info "Would sync $send_count file(s)" || true
        [ "$del_count" -gt 0 ] && log_info "Would delete $del_count file(s)" || true
        # Show file details
        local total line_num=0
        total=$(echo "$rsync_output" | wc -l | tr -d ' ')
        total=$((total + 0))
        # Wrap in subshell with explicit success to avoid set -e issues with read at EOF
        {
            while IFS= read -r line || [ -n "$line" ]; do
                [ $line_num -ge 15 ] && break
                [ -n "$line" ] && log_info "  ${DIM}$line${NC}"
                line_num=$((line_num + 1))
            done <<< "$rsync_output"
            true  # Explicit success
        }
        [ "$total" -gt 15 ] && log_info "  ${DIM}... and $((total - 15)) more${NC}" || true
    else
        # Run rsync - status 23/24 are partial transfer (permission issues) which we handle with fix_permissions
        local rsync_status=0
        rsync -avz --delete --exclude='homepage/logs/' "$LOCAL_INFRA_PATH/" "$PI_SSH_USER@$PI_HOST:$PI_INFRA_PATH/" >/dev/null 2>&1 || rsync_status=$?
        
        if [ "$rsync_status" -eq 0 ] || [ "$rsync_status" -eq 23 ] || [ "$rsync_status" -eq 24 ]; then
            [ "$send_count" -gt 0 ] && log_success "Synced $send_count file(s)" || true
            [ "$del_count" -gt 0 ] && log_success "Deleted $del_count obsolete file(s)" || true
        else
            log_error "File sync failed"
            return 1
        fi
    fi
}

# Fix permissions on remote
fix_permissions() {
    if [ "$DRY_RUN" = true ]; then
        return 0
    fi
    ssh "$PI_SSH_USER@$PI_HOST" "sudo chown -R $PI_SSH_USER:$PI_SSH_USER $PI_INFRA_PATH/" 2>/dev/null || true
}

# Pull images
pull_images() {
    if [ "$PULL_IMAGES" != true ]; then
        log_skip "Image pull skipped (use --pull)"
        return 0
    fi
    
    if [ "$DRY_RUN" = true ]; then
        log_info "Would pull latest images"
        return 0
    fi
    
    log_info "Pulling latest images..."
    if ssh "$PI_SSH_USER@$PI_HOST" "cd $PI_INFRA_PATH && docker compose pull" 2>/dev/null; then
        log_success "Images updated"
    else
        log_warning "Some images failed to pull"
    fi
}

# Check if stack exists
stack_exists() {
    ssh "$PI_SSH_USER@$PI_HOST" "docker stack ls --format '{{.Name}}' | grep -q '^infra$'" 2>/dev/null
}

# Get current service states
get_service_count() {
    ssh "$PI_SSH_USER@$PI_HOST" "docker stack services infra --format '{{.Name}}' 2>/dev/null | wc -l" || echo 0
}

# Remove stack (for full restart) - preserves volumes
remove_stack() {
    if ! stack_exists; then
        log_skip "No existing stack to remove"
        return 0
    fi
    
    if [ "$DRY_RUN" = true ]; then
        log_info "Would remove stack (named volumes preserved)"
        return 0
    fi
    
    log_info "Removing stack (named volumes preserved)..."
    ssh "$PI_SSH_USER@$PI_HOST" "docker stack rm infra" 2>/dev/null || true
    
    # Wait for complete removal
    local attempts=0
    while stack_exists && [ $attempts -lt 30 ]; do
        sleep 2
        ((attempts++)) || true
    done
    
    if stack_exists; then
        log_warning "Stack removal taking longer than expected"
    else
        log_success "Stack removed"
    fi
}

# Deploy stack
deploy_stack() {
    log_section "Deploying stack"
    
    local is_new=false
    if ! stack_exists; then
        is_new=true
    fi
    
    if [ "$DRY_RUN" = true ]; then
        if [ "$is_new" = true ]; then
            log_info "Would deploy new stack"
        else
            log_info "Would update existing stack (in-place)"
        fi
        
        # Parse compose file to show services (only under services: section)
        local services in_services=false
        services=""
        while IFS= read -r line; do
            # Start of services section
            [[ "$line" =~ ^services: ]] && in_services=true && continue
            # End of services section (another top-level key)
            [[ "$line" =~ ^[a-z] ]] && [[ ! "$line" =~ ^services: ]] && in_services=false
            # Service definition (exactly 2 spaces, then name:)
            if [ "$in_services" = true ] && [[ "$line" =~ ^\ \ [a-z][a-z0-9_-]*:$ ]]; then
                local svc_name
                svc_name=$(echo "$line" | sed 's/://g' | tr -d ' ')
                services+="$svc_name"$'\n'
            fi
        done < "$LOCAL_INFRA_PATH/docker-compose.yml"
        
        local svc_count=0
        while IFS= read -r svc; do
            [ -z "$svc" ] && continue
            ((svc_count++)) || true
            log_info "  ${DIM}$svc${NC}"
        done <<< "$services"
        SERVICES_TOTAL=$svc_count
        return 0
    fi
    
    # Check if configs need update (content changed) - requires full restart
    local local_ver remote_config_exists needs_restart=false
    local_ver=$(cat "$LOCAL_INFRA_PATH/VERSION" 2>/dev/null | tr -d '\n' || echo "")
    remote_config_exists=$(ssh "$PI_SSH_USER@$PI_HOST" "docker config ls --format '{{.Name}}' | grep -q '^infra_version_config$' && echo yes || echo no" 2>/dev/null)
    
    if [ "$remote_config_exists" = "yes" ] && [ "$is_new" = false ]; then
        local remote_ver
        remote_ver=$(ssh "$PI_SSH_USER@$PI_HOST" "docker config inspect infra_version_config --format '{{json .Spec.Data}}' 2>/dev/null | tr -d '\"' | base64 -d 2>/dev/null | tr -d '\n' || echo """)
        if [ "$local_ver" != "$remote_ver" ]; then
            log_warning "Config changed (v$remote_ver → v$local_ver) — requires restart"
            needs_restart=true
        fi
    fi
    
    # If config changed, need to remove stack first to allow config update
    if [ "$needs_restart" = true ]; then
        log_info "Removing stack for config update..."
        ssh "$PI_SSH_USER@$PI_HOST" "docker stack rm infra" >/dev/null 2>&1 || true
        # Wait for removal
        local attempts=0
        while stack_exists && [ $attempts -lt 30 ]; do
            sleep 2
            ((attempts++)) || true
        done
        # Remove the config
        ssh "$PI_SSH_USER@$PI_HOST" "docker config rm infra_version_config" >/dev/null 2>&1 || true
        log_success "Stack removed"
    fi
    
    # Deploy (docker stack deploy handles both create and update)
    log_info "Deploying..."
    if ssh "$PI_SSH_USER@$PI_HOST" "cd $PI_INFRA_PATH && docker stack deploy -c docker-compose.yml infra" >/dev/null 2>&1; then
        if [ "$is_new" = true ]; then
            log_success "Stack created"
        else
            log_success "Stack updated (in-place)"
        fi
    else
        log_error "Stack deployment failed"
        return 1
    fi
    
    SERVICES_TOTAL=$(get_service_count)
}

# Check service health
check_health() {
    log_section "Service status"
    
    if [ "$DRY_RUN" = true ]; then
        log_skip "Would verify service health"
        return 0
    fi
    
    # Wait for services to start
    sleep 5
    
    local services
    services=$(ssh "$PI_SSH_USER@$PI_HOST" "docker stack services infra --format '{{.Name}}\t{{.Replicas}}'" 2>/dev/null || true)
    
    if [ -z "$services" ]; then
        log_warning "No services found"
        return 0
    fi
    
    local healthy=0 starting=0 unhealthy=0
    
    while IFS=$'\t' read -r name replicas; do
        [ -z "$name" ] && continue
        local current desired
        current="${replicas%%/*}"
        desired="${replicas##*/}"
        local short_name="${name#infra_}"
        
        if [ "$current" = "$desired" ] && [ "$current" != "0" ]; then
            log_success "$short_name — $replicas"
            ((healthy++)) || true
        elif [ "$current" = "0" ]; then
            log_warning "$short_name — starting ($replicas)"
            ((starting++)) || true
        else
            log_warning "$short_name — $replicas"
            ((unhealthy++)) || true
        fi
    done <<< "$services"
    
    SERVICES_TOTAL=$((healthy + starting + unhealthy))
}

# Display summary
display_summary() {
    local local_ver
    local_ver=$(get_local_version)
    
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}  Summary${NC}"
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo -e "  ${CYAN}Version:${NC}   $local_ver"
    [ $FILES_SYNCED -gt 0 ]   && echo -e "  ${GREEN}Synced:${NC}    $FILES_SYNCED file(s)"
    [ $FILES_DELETED -gt 0 ]  && echo -e "  ${YELLOW}Removed:${NC}   $FILES_DELETED file(s)"
    [ $SERVICES_TOTAL -gt 0 ] && echo -e "  ${GREEN}Services:${NC}  $SERVICES_TOTAL"
    
    if [ $FILES_SYNCED -eq 0 ] && [ $FILES_DELETED -eq 0 ]; then
        echo -e "  ${DIM}No file changes${NC}"
    fi
    
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "  ${YELLOW}(dry-run mode — no changes made)${NC}"
    else
        echo -e "  ${DIM}Dashboard: https://portainer.home${NC}"
    fi
}

main() {
    parse_arguments "$@"
    validate_environment
    
    local local_version remote_version
    local_version=$(get_local_version)
    remote_version=$(get_remote_version)
    
    echo
    echo -e "${GREEN}🚀 Infra Stack Sync${NC}"
    echo -e "${DIM}   Target: $PI_SSH_USER@$PI_HOST${NC}"
    echo -e "${DIM}   Local:  v$local_version${NC}"
    echo -e "${DIM}   Remote: v$remote_version${NC}"
    [ "$DRY_RUN" = true ] && echo -e "${DIM}   Mode: dry-run${NC}"
    [ "$FULL_RESTART" = true ] && echo -e "${DIM}   Restart: full${NC}"
    [ "$PULL_IMAGES" = true ] && echo -e "${DIM}   Pull: enabled${NC}"
    echo
    
    echo -e "${BLUE}┌─${NC} ${CYAN}Infrastructure Deployment${NC}"
    
    test_ssh_connection
    log_success "SSH connected"
    
    log_section "Swarm"
    initialize_swarm
    
    sync_files
    fix_permissions
    
    log_section "Images"
    pull_images
    
    if [ "$FULL_RESTART" = true ]; then
        log_section "Full restart"
        remove_stack
    fi
    
    deploy_stack
    check_health
    
    log_end "Done"
    echo
    
    display_summary
}

main "$@"
