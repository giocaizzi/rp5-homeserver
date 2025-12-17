#!/bin/bash

# Sync and deploy infra stack on Raspberry Pi using Docker Swarm
# Usage: PI_SSH_USER=username [options] ./sync_infra.sh
# 
# Required environment variables:
#   PI_SSH_USER - SSH username for the Pi
# 
# Optional environment variables:
#   PI_HOST - Pi hostname or IP (default: pi.local)
#   PI_INFRA_PATH - Remote infra directory path (default: /home/${PI_SSH_USER}/rp5-homeserver/infra)
# 
# Options:
#   --pull        Pull latest Docker images before deploying stack
#   --help, -h    Show this help message

set -e  # Exit on any error

# Global configuration variables
PI_HOST="pi.local"
PI_INFRA_PATH=""
LOCAL_INFRA_PATH="$(dirname "$0")/../infra"

# Feature flags
PULL_IMAGES=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

success() {
    echo -e "${GREEN}✓ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

error() {
    echo -e "${RED}✗ $1${NC}"
}

# Show help message
show_help() {
    cat << EOF
Sync and deploy infra stack on Raspberry Pi using Docker Swarm

Usage: PI_SSH_USER=username [options] $0

Required environment variables:
  PI_SSH_USER     SSH username for the Pi

Optional environment variables:
  PI_HOST         Pi hostname or IP (default: pi.local)
  PI_INFRA_PATH   Remote infra directory path (default: /home/\${PI_SSH_USER}/rp5-homeserver/infra)

Options:
  --pull          Pull latest Docker images before deploying stack
  --help, -h      Show this help message

Examples:
  PI_SSH_USER=pi $0
  PI_SSH_USER=pi $0 --pull
  PI_SSH_USER=pi PI_HOST=192.168.1.100 $0 --pull
EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --pull)
                PULL_IMAGES=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                echo
                show_help
                exit 1
                ;;
        esac
    done
}

# Validate and set configuration
setup_configuration() {
    # Validate required environment variables
    if [ -z "$PI_SSH_USER" ]; then
        error "PI_SSH_USER environment variable is required"
        echo
        show_help
        exit 1
    fi
    
    # Set optional environment variables with defaults
    PI_HOST=${PI_HOST:-"pi.local"}
    PI_INFRA_PATH=${PI_INFRA_PATH:-"/home/${PI_SSH_USER}/rp5-homeserver/infra"}
    
    # Validate local infra directory exists
    if [ ! -d "$LOCAL_INFRA_PATH" ]; then
        error "Local infra directory not found: $LOCAL_INFRA_PATH"
        exit 1
    fi
}

# Test SSH connectivity
test_ssh_connection() {
    log "Testing SSH connection to $PI_SSH_USER@$PI_HOST..."
    if ! ssh -o ConnectTimeout=10 "$PI_SSH_USER@$PI_HOST" "echo 'SSH connection successful'" >/dev/null 2>&1; then
        error "Cannot connect to $PI_SSH_USER@$PI_HOST"
        exit 1
    fi
    success "SSH connection established"
}

# Initialize Docker Swarm if not already initialized
initialize_swarm() {
    log "Checking Docker Swarm status..."
    if ssh "$PI_SSH_USER@$PI_HOST" "docker info --format '{{.Swarm.LocalNodeState}}'" | grep -q "active"; then
        success "Docker Swarm already initialized"
    else
        log "Initializing Docker Swarm..."
        if ssh "$PI_SSH_USER@$PI_HOST" "docker swarm init"; then
            success "Docker Swarm initialized successfully"
        else
            error "Failed to initialize Docker Swarm"
            exit 1
        fi
    fi
}

# Fix file ownership on remote Pi
fix_remote_permissions() {
    log "Ensuring proper ownership of infra files..."
    ssh "$PI_SSH_USER@$PI_HOST" "sudo chown -R $PI_SSH_USER:$PI_SSH_USER $PI_INFRA_PATH/" || {
        warning "Could not fix ownership (continuing anyway)"
    }
}

# Read and display current version with banner
display_version_info() {
    if [ -f "$LOCAL_INFRA_PATH/VERSION" ]; then
        local version=$(cat "$LOCAL_INFRA_PATH/VERSION")
        echo
        echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║${NC}     ${BLUE}🚀 rp5-homeserver infra${NC}             ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}        ${YELLOW}Version: ${version}${NC}               ${GREEN}║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
        echo
        echo "$version"
    fi
}

# Sync local infra to Pi
sync_infra() {
    log "Syncing infra directory..."
    if rsync -avz --delete "$LOCAL_INFRA_PATH/" "$PI_SSH_USER@$PI_HOST:$PI_INFRA_PATH/"; then
        success "Infra sync completed"
    else
        error "Infra sync failed"
        exit 1
    fi
}

# Stop Docker Stack services
stop_services() {
    log "Stopping current infra stack..."
    if ssh "$PI_SSH_USER@$PI_HOST" "docker stack ls --format '{{.Name}}' | grep -q '^infra$'"; then
        ssh "$PI_SSH_USER@$PI_HOST" "docker stack rm infra" || {
            warning "Failed to stop stack (it may not be running)"
        }
        # Wait for stack to be completely removed
        log "Waiting for stack removal to complete..."
        while ssh "$PI_SSH_USER@$PI_HOST" "docker stack ls --format '{{.Name}}' | grep -q '^infra$'"; do
            sleep 2
        done
        success "Stack removed successfully"
    else
        log "No existing infra stack found"
    fi
}

# Pull Docker images if requested
pull_images() {
    if [ "$PULL_IMAGES" = true ]; then
        log "Pulling latest Docker images..."
        ssh "$PI_SSH_USER@$PI_HOST" "cd $PI_INFRA_PATH && docker-compose pull" || {
            warning "Failed to pull some images (continuing anyway)"
        }
    else
        log "Skipping image pull (use --pull flag to update images)"
    fi
}

# Deploy Docker Stack services
deploy_services() {
    log "Deploying infra stack..."
    if ssh "$PI_SSH_USER@$PI_HOST" "cd $PI_INFRA_PATH && docker stack deploy -c docker-compose.yml infra"; then
        success "Infra stack deployed successfully"
    else
        error "Failed to deploy infra stack"
        exit 1
    fi
}

# Check final service status
check_service_status() {
    log "Checking stack status..."
    sleep 10  # Wait for services to start
    ssh "$PI_SSH_USER@$PI_HOST" "docker stack ps infra"
    echo
    log "Stack services overview:"
    ssh "$PI_SSH_USER@$PI_HOST" "docker stack services infra"
}

# Main execution function
main() {
    # Parse command line arguments
    parse_arguments "$@"
    
    # Setup and validate configuration
    setup_configuration
    
    # Display execution info
    log "Starting infra sync and stack deployment process"
    log "SSH User: $PI_SSH_USER"
    log "Pi Host: $PI_HOST"
    log "Remote Path: $PI_INFRA_PATH"
    log "Pull Images: $PULL_IMAGES"
    
    # Execute deployment steps
    test_ssh_connection
    initialize_swarm
    fix_remote_permissions
    local version=$(display_version_info)
    sync_infra
    stop_services
    pull_images
    deploy_services
    check_service_status
    
    # Success message
    success "Infra sync and stack deployment completed successfully!"
    if [ -n "$version" ]; then
        log "Deployed version: $version"
    fi
    log "Access Portainer at: https://portainer.home"
}

# Execute main function with all arguments
main "$@"