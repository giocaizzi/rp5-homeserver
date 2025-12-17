#!/bin/bash

# Diagnose and kill stuck Docker/Portainer processes on Raspberry Pi
# Targets: compose-unpacker, docker stack rm, and similar operations
#
# Usage: PI_SSH_USER=username ./kill_stuck_processes.sh [options]
#
# Required environment variables:
#   PI_SSH_USER - SSH username for the Pi
#
# Optional environment variables:
#   PI_HOST - Pi hostname or IP (default: pi.local)

set -euo pipefail

# Global configuration
PI_HOST="${PI_HOST:-pi.local}"
CPU_THRESHOLD="${CPU_THRESHOLD:-10}"
RUNTIME_THRESHOLD="${RUNTIME_THRESHOLD:-300}"  # 5 minutes in seconds

# Feature flags
DRY_RUN=false
FORCE=false

# Counters
PROCESSES_FOUND=0
PROCESSES_KILLED=0

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
Diagnose and kill stuck Docker/Portainer processes on Raspberry Pi

Usage: PI_SSH_USER=username $0 [options]

Required environment variables:
  PI_SSH_USER       SSH username for the Pi

Optional environment variables:
  PI_HOST           Pi hostname or IP (default: pi.local)
  CPU_THRESHOLD     Minimum CPU% to consider (default: 10)
  RUNTIME_THRESHOLD Minimum runtime in seconds (default: 300)

Options:
  --dry-run         Show stuck processes without killing
  --force           Kill without confirmation prompt
  --help, -h        Show this help message

Detected patterns:
  - compose-unpacker swarm-undeploy (Portainer stack removal)
  - docker stack rm --detach=false (blocking stack removal)
  - docker service update (stuck service updates)

Examples:
  PI_SSH_USER=pi $0                    # Interactive mode
  PI_SSH_USER=pi $0 --dry-run          # Diagnose only
  PI_SSH_USER=pi $0 --force            # Kill without prompt
  CPU_THRESHOLD=5 PI_SSH_USER=pi $0    # Lower CPU threshold
EOF
}

parse_arguments() {
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
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

validate_environment() {
    if [[ -z "${PI_SSH_USER:-}" ]]; then
        log_error "PI_SSH_USER environment variable is required"
        echo ""
        show_help
        exit 1
    fi
}

ssh_cmd() {
    ssh -o ConnectTimeout=10 -o BatchMode=yes "${PI_SSH_USER}@${PI_HOST}" "$@"
}

test_connection() {
    log_section "Testing SSH connection"
    if ssh_cmd "echo 'ok'" &>/dev/null; then
        log_success "Connected to ${PI_SSH_USER}@${PI_HOST}"
        return 0
    else
        log_error "Failed to connect to ${PI_SSH_USER}@${PI_HOST}"
        exit 1
    fi
}

# Convert elapsed time string (e.g., "01:23:45" or "23:45") to seconds
parse_elapsed() {
    local elapsed="$1"
    local seconds=0
    
    # Handle formats: HH:MM:SS, MM:SS, or just SS
    IFS=':' read -ra parts <<< "$elapsed"
    local len=${#parts[@]}
    
    if [[ $len -eq 3 ]]; then
        seconds=$((10#${parts[0]} * 3600 + 10#${parts[1]} * 60 + 10#${parts[2]}))
    elif [[ $len -eq 2 ]]; then
        seconds=$((10#${parts[0]} * 60 + 10#${parts[1]}))
    else
        seconds=$((10#${parts[0]}))
    fi
    
    echo "$seconds"
}

find_stuck_processes() {
    log_section "Scanning for stuck processes"
    
    # Patterns to detect stuck processes
    local patterns=(
        "compose-unpacker swarm-undeploy"
        "docker stack rm"
        "docker service update.*--force"
        "docker service rm"
    )
    
    local pattern_regex
    pattern_regex=$(printf "%s|" "${patterns[@]}")
    pattern_regex="${pattern_regex%|}"  # Remove trailing |
    
    # Get process info: PID, CPU%, ELAPSED, COMMAND
    local ps_output
    ps_output=$(ssh_cmd "ps -eo pid,pcpu,etime,args --no-headers 2>/dev/null | grep -E '${pattern_regex}' | grep -v grep || true")
    
    if [[ -z "$ps_output" ]]; then
        log_info "No matching processes found"
        return 0
    fi
    
    # Store found processes
    STUCK_PIDS=()
    STUCK_INFO=()
    
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        
        local pid cpu elapsed cmd
        pid=$(echo "$line" | awk '{print $1}')
        cpu=$(echo "$line" | awk '{print $2}')
        elapsed=$(echo "$line" | awk '{print $3}')
        cmd=$(echo "$line" | awk '{$1=$2=$3=""; print $0}' | sed 's/^ *//')
        
        # Convert elapsed to seconds
        local elapsed_sec
        elapsed_sec=$(parse_elapsed "$elapsed")
        
        # Check thresholds
        local cpu_int=${cpu%.*}  # Remove decimal
        if [[ $cpu_int -ge $CPU_THRESHOLD ]] && [[ $elapsed_sec -ge $RUNTIME_THRESHOLD ]]; then
            STUCK_PIDS+=("$pid")
            STUCK_INFO+=("PID=$pid CPU=${cpu}% Runtime=${elapsed} CMD=${cmd:0:60}...")
            PROCESSES_FOUND=$((PROCESSES_FOUND + 1))
        fi
    done <<< "$ps_output"
    
    if [[ $PROCESSES_FOUND -eq 0 ]]; then
        log_info "No processes exceed thresholds (CPU≥${CPU_THRESHOLD}%, runtime≥${RUNTIME_THRESHOLD}s)"
        return 0
    fi
    
    log_warning "Found ${PROCESSES_FOUND} stuck process(es):"
    for info in "${STUCK_INFO[@]}"; do
        log_info "  $info"
    done
    
    return 0
}

kill_processes() {
    if [[ $PROCESSES_FOUND -eq 0 ]]; then
        return 0
    fi
    
    log_section "Kill stuck processes"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_skip "Dry run - would kill PIDs: ${STUCK_PIDS[*]}"
        return 0
    fi
    
    # Confirmation prompt unless --force
    if [[ "$FORCE" != "true" ]]; then
        echo -e "${YELLOW}Kill ${PROCESSES_FOUND} process(es)? [y/N]${NC} "
        read -r confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log_skip "Aborted by user"
            return 0
        fi
    fi
    
    # Kill processes
    local pids_str="${STUCK_PIDS[*]}"
    if ssh_cmd "sudo kill ${pids_str}" 2>/dev/null; then
        PROCESSES_KILLED=$PROCESSES_FOUND
        log_success "Killed ${PROCESSES_KILLED} process(es)"
    else
        log_error "Failed to kill some processes"
        return 1
    fi
    
    # Verify they're gone
    sleep 2
    local remaining
    remaining=$(ssh_cmd "ps -p ${pids_str} --no-headers 2>/dev/null | wc -l" || echo "0")
    
    if [[ "$remaining" -gt 0 ]]; then
        log_warning "${remaining} process(es) still running, sending SIGKILL"
        ssh_cmd "sudo kill -9 ${pids_str}" 2>/dev/null || true
    fi
    
    return 0
}

show_current_status() {
    log_section "Current system status"
    
    # Top CPU consumers
    local top_procs
    top_procs=$(ssh_cmd "ps aux --sort=-%cpu | head -6 | tail -5" 2>/dev/null || true)
    
    log_info "Top CPU processes:"
    while IFS= read -r line; do
        local user pid cpu cmd
        user=$(echo "$line" | awk '{print $1}')
        pid=$(echo "$line" | awk '{print $2}')
        cpu=$(echo "$line" | awk '{print $3}')
        cmd=$(echo "$line" | awk '{print $11}' | head -c 40)
        log_info "  ${cpu}% ${user}:${pid} ${cmd}"
    done <<< "$top_procs"
}

print_summary() {
    echo ""
    echo -e "${BLUE}┌─${NC} ${CYAN}Summary${NC}"
    log_info "Processes found: ${PROCESSES_FOUND}"
    log_info "Processes killed: ${PROCESSES_KILLED}"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_end "${YELLOW}Dry run complete${NC}"
    elif [[ $PROCESSES_KILLED -gt 0 ]]; then
        log_end "${GREEN}Done${NC}"
    else
        log_end "${GREEN}No action needed${NC}"
    fi
}

main() {
    parse_arguments "$@"
    validate_environment
    
    echo -e "${BLUE}┌─${NC} ${CYAN}Kill Stuck Processes${NC}"
    [[ "$DRY_RUN" == "true" ]] && log_info "${YELLOW}DRY RUN MODE${NC}"
    
    test_connection
    find_stuck_processes
    kill_processes
    show_current_status
    print_summary
}

main "$@"
