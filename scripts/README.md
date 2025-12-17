# Scripts

Automation scripts for managing the Raspberry Pi home server.

## Usage

All scripts require environment variables for configuration. No sensitive defaults are provided.

### sync_infra.sh

Syncs the local infra directory to the Raspberry Pi and deploys the infrastructure stack using Docker Swarm.

**Required Environment Variables:**
- `PI_SSH_USER` - SSH username for the Pi

**Optional Environment Variables:**
- `PI_HOST` - Pi hostname or IP (default: `pi.local`)
- `PI_INFRA_PATH` - Remote infra directory path (default: `/home/${PI_SSH_USER}/rp5-homeserver/infra`)

**Usage:**
```bash
# Basic usage
PI_SSH_USER=pi ./sync_infra.sh

# With image pull
PI_SSH_USER=pi ./sync_infra.sh --pull

# Show help
./sync_infra.sh --help

# With custom host
PI_SSH_USER=pi PI_HOST=192.168.1.100 ./sync_infra.sh

# With custom paths and image pull
PI_SSH_USER=pi PI_INFRA_PATH=/opt/homeserver/infra ./sync_infra.sh --pull
```

**What it does:**
1. Tests SSH connection to the Pi
2. Initializes Docker Swarm if not already initialized
3. Fixes ownership permissions on remote infra directory
4. Syncs local infra directory to Pi using rsync
5. Removes current Docker Swarm stack if it exists
6. Optionally pulls latest Docker images (with `--pull` flag)
7. Deploys the stack using `docker stack deploy`
8. Shows final stack status and services

---

### create_secrets.sh

Creates Docker Swarm external secrets for a specified service stack. Used for services deployed via Portainer Remote Stacks.

**Required Environment Variables:**
- `PI_SSH_USER` - SSH username for the Pi

**Optional Environment Variables:**
- `PI_HOST` - Pi hostname or IP (default: `pi.local`)

**Arguments:**
- `<stack>` - Stack name (e.g., `n8n`, `firefly`, `langfuse`, `observability`)

**Usage:**
```bash
# Create secrets for n8n stack
PI_SSH_USER=pi ./create_secrets.sh n8n

# Dry run - show what would be created
PI_SSH_USER=pi ./create_secrets.sh firefly --dry-run

# Force recreate existing secrets
PI_SSH_USER=pi ./create_secrets.sh langfuse --force

# Show help
./create_secrets.sh --help
```

**What it does:**
1. Parses external secrets from the stack's `docker-compose.yml`
2. Maps secret names to local files in `services/<stack>/secrets/`
3. Creates Docker Swarm secrets on the Pi via SSH
4. Follows naming convention: `<stack>_<secret_name>`

**Secret naming convention:**
| Stack | Local File | Swarm Secret Name |
|-------|------------|-------------------|
| n8n | `secrets/postgres_password.txt` | `n8n_postgres_password` |
| firefly | `secrets/app_key.txt` | `firefly_app_key` |
| langfuse | `secrets/salt.txt` | `langfuse_salt` |

---

### kill_stuck_processes.sh

Diagnoses and kills stuck Docker/Portainer processes on the Raspberry Pi. Targets common stuck operations like `compose-unpacker swarm-undeploy` and `docker stack rm --detach=false`.

**Required Environment Variables:**
- `PI_SSH_USER` - SSH username for the Pi

**Optional Environment Variables:**
- `PI_HOST` - Pi hostname or IP (default: `pi.local`)
- `CPU_THRESHOLD` - Minimum CPU% to consider stuck (default: `10`)
- `RUNTIME_THRESHOLD` - Minimum runtime in seconds (default: `300`)

**Usage:**
```bash
# Diagnose only (dry run)
PI_SSH_USER=pi ./kill_stuck_processes.sh --dry-run

# Interactive mode (prompts before killing)
PI_SSH_USER=pi ./kill_stuck_processes.sh

# Kill without confirmation
PI_SSH_USER=pi ./kill_stuck_processes.sh --force

# Lower thresholds for detection
CPU_THRESHOLD=5 RUNTIME_THRESHOLD=120 PI_SSH_USER=pi ./kill_stuck_processes.sh
```

**What it does:**
1. Scans for processes matching stuck patterns (compose-unpacker, docker stack rm, etc.)
2. Filters by CPU usage and runtime thresholds
3. Displays stuck processes with details
4. Optionally kills them (with confirmation or --force)
5. Shows current system status after cleanup

**Detected patterns:**
- `compose-unpacker swarm-undeploy` - Portainer stack removal
- `docker stack rm --detach=false` - Blocking stack removal
- `docker service update` - Stuck service updates

---

## Adding New Scripts

When adding new scripts to this directory:

1. Use environment variables for all configuration
2. Provide no sensitive defaults
3. Include comprehensive error handling
4. Add colored output for better UX
5. Document required and optional environment variables
6. Update this README with usage instructions