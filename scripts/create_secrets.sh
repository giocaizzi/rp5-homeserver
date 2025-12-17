#!/bin/bash

# Create Docker Swarm secrets for a specified service stack
# Usage: PI_SSH_USER=username ./create_secrets.sh <stack>
# 
# Required environment variables:
#   PI_SSH_USER - SSH username for the Pi
# 
# Optional environment variables:
#   PI_HOST - Pi hostname or IP (default: pi.local)
# 
# Arguments:
#   <stack> - Stack name (e.g., n8n, firefly, langfuse, observability)
# 
# Options:
#   --dry-run     Show what would be created without executing
#   --force       Remove and recreate existing secrets
#   --help, -h    Show this help message

set -e

# Global configuration
PI_HOST="pi.local"
REPO_ROOT="$(dirname "$0")/.."

# Feature flags
DRY_RUN=false
FORCE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging functions
log() { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"; }
success() { echo -e "${GREEN}✓ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
error() { echo -e "${RED}✗ $1${NC}"; }
info() { echo -e "${CYAN}ℹ $1${NC}"; }

# Show help message
show_help() {
    cat << EOF
Create Docker Swarm secrets for a specified service stack

Usage: PI_SSH_USER=username $0 <stack> [options]

Required environment variables:
  PI_SSH_USER     SSH username for the Pi

Optional environment variables:
  PI_HOST         Pi hostname or IP (default: pi.local)

Arguments:
  <stack>         Stack name: n8n, firefly, langfuse, observability

Options:
  --dry-run       Show what would be created without executing
  --force         Remove and recreate existing secrets
  --help, -h      Show this help message

Examples:
  PI_SSH_USER=pi $0 n8n
  PI_SSH_USER=pi $0 firefly --dry-run
  PI_SSH_USER=pi $0 langfuse --force

Secret naming convention:
  External secrets use pattern: <stack>_<secret_name>
  Example: n8n_postgres_password, firefly_app_key
EOF
}

# Parse command line arguments
parse_arguments() {
    STACK=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            -*)
                error "Unknown option: $1"
                echo
                show_help
                exit 1
                ;;
            *)
                if [ -z "$STACK" ]; then
                    STACK="$1"
                else
                    error "Unexpected argument: $1"
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    if [ -z "$STACK" ]; then
        error "Stack name is required"
        echo
        show_help
        exit 1
    fi
}

# Validate configuration
setup_configuration() {
    if [ -z "$PI_SSH_USER" ]; then
        error "PI_SSH_USER environment variable is required"
        echo
        show_help
        exit 1
    fi
    
    PI_HOST=${PI_HOST:-"pi.local"}
    
    # Validate stack exists
    local stack_path="$REPO_ROOT/services/$STACK"
    if [ ! -d "$stack_path" ]; then
        error "Stack not found: $STACK"
        info "Available stacks:"
        ls -1 "$REPO_ROOT/services/" | sed 's/^/  - /'
        exit 1
    fi
    
    # Validate secrets directory exists
    SECRETS_DIR="$stack_path/secrets"
    if [ ! -d "$SECRETS_DIR" ]; then
        error "Secrets directory not found: $SECRETS_DIR"
        exit 1
    fi
}

# Display banner
display_banner() {
    echo
    echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}     ${BLUE}🔐 Docker Swarm Secrets${NC}            ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}        ${YELLOW}Stack: ${STACK}${NC}$(printf '%*s' $((22 - ${#STACK})) '')${GREEN}║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
    echo
}

# Get list of secret files from compose
get_secrets_from_compose() {
    local compose_file="$REPO_ROOT/services/$STACK/docker-compose.yml"
    
    if [ ! -f "$compose_file" ]; then
        error "docker-compose.yml not found for stack: $STACK"
        exit 1
    fi
    
    # Extract external secret names from compose file
    # Pattern: name: <stack>_<secret_name>
    grep -A1 "external: true" "$compose_file" | grep "name:" | sed 's/.*name: //' | sort -u
}

# Map secret name to local file
get_secret_file() {
    local secret_name="$1"
    local stack_prefix="${STACK}_"
    
    # Remove stack prefix to get local filename
    local local_name="${secret_name#$stack_prefix}"
    local secret_file="$SECRETS_DIR/${local_name}.txt"
    
    # Handle special cases (json files, etc.)
    if [ ! -f "$secret_file" ]; then
        secret_file="$SECRETS_DIR/${local_name}.json"
    fi
    
    echo "$secret_file"
}

# Check if secret exists on Pi
secret_exists() {
    local secret_name="$1"
    ssh "$PI_SSH_USER@$PI_HOST" "docker secret ls --format '{{.Name}}' | grep -q '^${secret_name}$'" 2>/dev/null
}

# Create a single secret
create_secret() {
    local secret_name="$1"
    local secret_file="$2"
    
    if [ ! -f "$secret_file" ]; then
        warning "Secret file not found: $secret_file (skipping $secret_name)"
        return 1
    fi
    
    if secret_exists "$secret_name"; then
        if [ "$FORCE" = true ]; then
            if [ "$DRY_RUN" = true ]; then
                info "[DRY-RUN] Would remove and recreate: $secret_name"
            else
                log "Removing existing secret: $secret_name"
                ssh "$PI_SSH_USER@$PI_HOST" "docker secret rm $secret_name" || {
                    warning "Failed to remove $secret_name (may be in use)"
                    return 1
                }
            fi
        else
            info "Secret already exists: $secret_name (use --force to recreate)"
            return 0
        fi
    fi
    
    if [ "$DRY_RUN" = true ]; then
        info "[DRY-RUN] Would create: $secret_name <- $(basename "$secret_file")"
    else
        log "Creating secret: $secret_name"
        cat "$secret_file" | ssh "$PI_SSH_USER@$PI_HOST" "docker secret create $secret_name -" && \
            success "Created: $secret_name" || {
            error "Failed to create: $secret_name"
            return 1
        }
    fi
}

# Test SSH connection
test_ssh_connection() {
    log "Testing SSH connection to $PI_SSH_USER@$PI_HOST..."
    if ! ssh -o ConnectTimeout=10 "$PI_SSH_USER@$PI_HOST" "echo 'OK'" >/dev/null 2>&1; then
        error "Cannot connect to $PI_SSH_USER@$PI_HOST"
        exit 1
    fi
    success "SSH connection established"
}

# List existing secrets for stack
list_existing_secrets() {
    log "Existing secrets for $STACK on Pi:"
    local secrets=$(ssh "$PI_SSH_USER@$PI_HOST" "docker secret ls --format '{{.Name}}' | grep '^${STACK}_' || true")
    if [ -n "$secrets" ]; then
        echo "$secrets" | while read -r name; do
            echo "  - $name"
        done
    else
        info "  (none)"
    fi
}

# Main execution
main() {
    parse_arguments "$@"
    setup_configuration
    display_banner
    
    # Show configuration
    log "Configuration:"
    echo "  SSH Target: $PI_SSH_USER@$PI_HOST"
    echo "  Stack: $STACK"
    echo "  Secrets Dir: $SECRETS_DIR"
    echo "  Dry Run: $DRY_RUN"
    echo "  Force: $FORCE"
    echo
    
    if [ "$DRY_RUN" = false ]; then
        test_ssh_connection
        list_existing_secrets
        echo
    fi
    
    # Get secrets from compose file
    local secrets=$(get_secrets_from_compose)
    
    if [ -z "$secrets" ]; then
        warning "No external secrets found in docker-compose.yml"
        exit 0
    fi
    
    log "Processing secrets from docker-compose.yml..."
    echo
    
    local created=0
    local skipped=0
    local failed=0
    
    echo "$secrets" | while read -r secret_name; do
        local secret_file=$(get_secret_file "$secret_name")
        
        if create_secret "$secret_name" "$secret_file"; then
            ((created++)) || true
        else
            ((failed++)) || true
        fi
    done
    
    echo
    if [ "$DRY_RUN" = true ]; then
        success "Dry run completed"
    else
        success "Secret creation completed for stack: $STACK"
        echo
        list_existing_secrets
    fi
}

main "$@"
