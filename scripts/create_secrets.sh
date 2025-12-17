#!/bin/bash

# Sync Docker Swarm secrets for service stacks
# Creates, updates, and prunes secrets based on local files
#
# Usage: PI_SSH_USER=username ./create_secrets.sh <stack|--all> [options]
#
# Required environment variables:
#   PI_SSH_USER - SSH username for the Pi
#
# Optional environment variables:
#   PI_HOST - Pi hostname or IP (default: pi.local)

set -euo pipefail

# Global configuration
PI_HOST="${PI_HOST:-pi.local}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Feature flags
DRY_RUN=false
PRUNE=false
ALL_STACKS=false

# Counters (use : to avoid set -e issues with arithmetic)
TOTAL_CREATED=0
TOTAL_UPDATED=0
TOTAL_UNCHANGED=0
TOTAL_PRUNED=0
TOTAL_FAILED=0

incr_created()   { TOTAL_CREATED=$((TOTAL_CREATED + 1)); }
incr_updated()   { TOTAL_UPDATED=$((TOTAL_UPDATED + 1)); }
incr_unchanged() { TOTAL_UNCHANGED=$((TOTAL_UNCHANGED + 1)); }
incr_pruned()    { TOTAL_PRUNED=$((TOTAL_PRUNED + 1)); }
incr_failed()    { TOTAL_FAILED=$((TOTAL_FAILED + 1)); }

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
DIM='\033[2m'
NC='\033[0m'

# Logging
log_info()    { echo -e "${BLUE}│${NC} $1"; }
log_success() { echo -e "${BLUE}│${NC} ${GREEN}✓${NC} $1"; }
log_warning() { echo -e "${BLUE}│${NC} ${YELLOW}⚠${NC} $1"; }
log_error()   { echo -e "${BLUE}│${NC} ${RED}✗${NC} $1"; }
log_skip()    { echo -e "${BLUE}│${NC} ${DIM}─${NC} $1"; }
log_section() { echo -e "${BLUE}├─${NC} ${CYAN}$1${NC}"; }
log_end()     { echo -e "${BLUE}└─${NC} $1"; }

show_help() {
    cat << EOF
Sync Docker Swarm secrets for service stacks

Usage: PI_SSH_USER=username $0 <stack|--all> [options]

Required environment variables:
  PI_SSH_USER     SSH username for the Pi

Optional environment variables:
  PI_HOST         Pi hostname or IP (default: pi.local)

Arguments:
  <stack>         Stack name: n8n, firefly, langfuse, observability
  --all           Process all stacks in services/ folder

Options:
  --dry-run       Show what would be done without executing
  --prune         Remove secrets on Pi not found in local files
  --help, -h      Show this help message

Operations:
  CREATE          Secret doesn't exist on Pi → create it
  UPDATE          Secret exists but value differs → recreate it
  UNCHANGED       Secret exists with same value → skip
  PRUNE           Secret on Pi not in compose file → remove (with --prune)

Examples:
  PI_SSH_USER=pi $0 n8n
  PI_SSH_USER=pi $0 --all --dry-run
  PI_SSH_USER=pi $0 langfuse --prune
EOF
}

parse_arguments() {
    STACKS=()

    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --prune)
                PRUNE=true
                shift
                ;;
            --all)
                ALL_STACKS=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            -*)
                echo -e "${RED}Unknown option: $1${NC}" >&2
                show_help
                exit 1
                ;;
            *)
                STACKS+=("$1")
                shift
                ;;
        esac
    done

    if [ "$ALL_STACKS" = true ]; then
        STACKS=()
        for dir in "$REPO_ROOT/services/"*/; do
            if [ -d "${dir}secrets" ]; then
                STACKS+=("$(basename "$dir")")
            fi
        done
    fi

    if [ ${#STACKS[@]} -eq 0 ]; then
        echo -e "${RED}Error: Stack name or --all required${NC}" >&2
        echo
        show_help
        exit 1
    fi
}

validate_environment() {
    if [ -z "$PI_SSH_USER" ]; then
        echo -e "${RED}Error: PI_SSH_USER environment variable required${NC}" >&2
        exit 1
    fi
}

test_ssh_connection() {
    if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "$PI_SSH_USER@$PI_HOST" "true" 2>/dev/null; then
        echo -e "${RED}Error: Cannot connect to $PI_SSH_USER@$PI_HOST${NC}" >&2
        exit 1
    fi
}

# Get external secrets defined in compose file
get_compose_secrets() {
    local stack="$1"
    local compose_file="$REPO_ROOT/services/$stack/docker-compose.yml"

    if [ ! -f "$compose_file" ]; then
        return
    fi

    grep -A1 "external: true" "$compose_file" 2>/dev/null | grep "name:" | sed 's/.*name: //' | tr -d ' ' | sort -u
}

# Get local secret file path for a secret name
get_local_secret_file() {
    local stack="$1"
    local secret_name="$2"
    local secrets_dir="$REPO_ROOT/services/$stack/secrets"
    local local_name="${secret_name#${stack}_}"

    for ext in txt json key pem; do
        local file="$secrets_dir/${local_name}.$ext"
        if [ -f "$file" ]; then
            echo "$file"
            return
        fi
    done
    
    # Return expected path even if not found (for error messages)
    echo "$secrets_dir/${local_name}.txt"
}

# Get secret value from Pi (via temporary service)
get_remote_secret_value() {
    local secret_name="$1"

    # Check if secret exists
    if ! ssh "$PI_SSH_USER@$PI_HOST" "docker secret inspect $secret_name" &>/dev/null; then
        return 1
    fi

    # Read secret value via temporary container
    ssh "$PI_SSH_USER@$PI_HOST" "
        docker service create --name tmp_secret_read_$$ --secret $secret_name --restart-condition=none --quiet alpine cat /run/secrets/$secret_name 2>/dev/null
        sleep 2
        docker service logs tmp_secret_read_$$ 2>/dev/null | head -1
        docker service rm tmp_secret_read_$$ >/dev/null 2>&1
    " 2>/dev/null
}

# Get existing secrets on Pi for a stack
get_remote_secrets() {
    local stack="$1"
    ssh "$PI_SSH_USER@$PI_HOST" "docker secret ls --format '{{.Name}}' | grep '^${stack}_' || true" 2>/dev/null
}

# Create or update a secret
sync_secret() {
    local stack="$1"
    local secret_name="$2"
    local local_file="$3"
    local local_name="${secret_name#${stack}_}"

    if [ ! -f "$local_file" ]; then
        log_warning "$secret_name — missing file: ${local_name}.txt"
        incr_failed
        return 1
    fi

    local local_value
    local_value=$(cat "$local_file")
    
    # Calculate local hash
    local local_hash
    local_hash=$(echo -n "$local_value" | sha256sum | cut -d' ' -f1 | head -c 12)

    # Check if secret exists on Pi
    local remote_hash=""
    local secret_exists=false
    
    if ssh "$PI_SSH_USER@$PI_HOST" "docker secret inspect $secret_name" &>/dev/null; then
        secret_exists=true
        remote_hash=$(ssh "$PI_SSH_USER@$PI_HOST" "docker secret inspect $secret_name --format '{{index .Spec.Labels \"hash\"}}'" 2>/dev/null || echo "")
    fi

    if [ "$secret_exists" = true ]; then
        if [ "$local_hash" = "$remote_hash" ]; then
            log_skip "$secret_name — unchanged (hash: $local_hash)"
            incr_unchanged
        else
            if [ "$DRY_RUN" = true ]; then
                if [ -z "$remote_hash" ]; then
                    log_info "$secret_name — would update (no hash → $local_hash)"
                else
                    log_info "$secret_name — would update (hash: $remote_hash → $local_hash)"
                fi
                incr_updated
            else
                # Need to update - remove and recreate
                if ssh "$PI_SSH_USER@$PI_HOST" "docker secret rm $secret_name" 2>/dev/null; then
                    if echo -n "$local_value" | ssh "$PI_SSH_USER@$PI_HOST" "docker secret create --label hash=$local_hash $secret_name -" >/dev/null; then
                        log_success "$secret_name — ${YELLOW}updated${NC} (hash: $local_hash)"
                        incr_updated
                    else
                        log_error "$secret_name — failed to recreate"
                        incr_failed
                    fi
                else
                    log_warning "$secret_name — cannot update (in use by service)"
                    incr_unchanged
                fi
            fi
        fi
    else
        # Secret doesn't exist - create it
        if [ "$DRY_RUN" = true ]; then
            log_info "$secret_name — would create (hash: $local_hash)"
            incr_created
        else
            if echo -n "$local_value" | ssh "$PI_SSH_USER@$PI_HOST" "docker secret create --label hash=$local_hash $secret_name -" >/dev/null; then
                log_success "$secret_name — ${GREEN}created${NC} (hash: $local_hash)"
                incr_created
            else
                log_error "$secret_name — failed to create"
                incr_failed
            fi
        fi
    fi
}

# Prune secrets not in compose file
prune_orphan_secrets() {
    local stack="$1"
    local -a compose_secrets=()
    local -a remote_secrets=()

    # Get secrets defined in compose
    while IFS= read -r secret; do
        [ -n "$secret" ] && compose_secrets+=("$secret")
    done < <(get_compose_secrets "$stack")

    # Get secrets on Pi
    while IFS= read -r secret; do
        [ -n "$secret" ] && remote_secrets+=("$secret")
    done < <(get_remote_secrets "$stack")

    # Find orphans
    for remote in "${remote_secrets[@]}"; do
        local found=false
        for compose in "${compose_secrets[@]}"; do
            if [ "$remote" = "$compose" ]; then
                found=true
                break
            fi
        done

        if [ "$found" = false ]; then
            if [ "$DRY_RUN" = true ]; then
                log_info "$remote — would prune (not in compose)"
                incr_pruned
            else
                if ssh "$PI_SSH_USER@$PI_HOST" "docker secret rm $remote" 2>/dev/null; then
                    log_success "$remote — ${RED}pruned${NC}"
                    incr_pruned
                else
                    log_warning "$remote — cannot prune (in use)"
                fi
            fi
        fi
    done
}

# Process a single stack
process_stack() {
    local stack="$1"
    local secrets_dir="$REPO_ROOT/services/$stack/secrets"

    echo -e "${BLUE}┌─${NC} ${CYAN}Stack: $stack${NC}"

    if [ ! -d "$secrets_dir" ]; then
        log_warning "No secrets directory"
        log_end "Skipped"
        echo
        return
    fi

    # Get secrets from compose
    local compose_secrets
    compose_secrets=$(get_compose_secrets "$stack")

    if [ -z "$compose_secrets" ]; then
        log_info "No external secrets in compose"
        log_end "Done"
        echo
        return
    fi

    # Sync each secret
    log_section "Syncing secrets"
    while IFS= read -r secret_name; do
        [ -z "$secret_name" ] && continue
        local local_file
        local_file=$(get_local_secret_file "$stack" "$secret_name")
        sync_secret "$stack" "$secret_name" "$local_file" || true
    done <<< "$compose_secrets"

    # Prune if requested
    if [ "$PRUNE" = true ]; then
        log_section "Pruning orphans"
        prune_orphan_secrets "$stack"
    fi

    log_end "Done"
    echo
}

# Display summary
display_summary() {
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}  Summary${NC}"
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    [ $TOTAL_CREATED -gt 0 ]   && echo -e "  ${GREEN}Created:${NC}   $TOTAL_CREATED"
    [ $TOTAL_UPDATED -gt 0 ]   && echo -e "  ${YELLOW}Updated:${NC}   $TOTAL_UPDATED"
    [ $TOTAL_UNCHANGED -gt 0 ] && echo -e "  ${DIM}Unchanged:${NC} $TOTAL_UNCHANGED"
    [ $TOTAL_PRUNED -gt 0 ]    && echo -e "  ${RED}Pruned:${NC}    $TOTAL_PRUNED"
    [ $TOTAL_FAILED -gt 0 ]    && echo -e "  ${RED}Missing:${NC}   $TOTAL_FAILED ${DIM}(local files not found)${NC}"
    echo -e "${GREEN}═══════════════════════════════════════${NC}"

    if [ "$DRY_RUN" = true ]; then
        echo -e "  ${YELLOW}(dry-run mode — no changes made)${NC}"
    fi
}

main() {
    parse_arguments "$@"
    validate_environment

    echo
    echo -e "${GREEN}🔐 Docker Swarm Secrets Sync${NC}"
    echo -e "${DIM}   Target: $PI_SSH_USER@$PI_HOST${NC}"
    [ "$DRY_RUN" = true ] && echo -e "${DIM}   Mode: dry-run${NC}"
    [ "$PRUNE" = true ] && echo -e "${DIM}   Prune: enabled${NC}"
    echo

    test_ssh_connection

    for stack in "${STACKS[@]}"; do
        process_stack "$stack"
    done

    display_summary
}

main "$@"
