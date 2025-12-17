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

## Adding New Scripts

When adding new scripts to this directory:

1. Use environment variables for all configuration
2. Provide no sensitive defaults
3. Include comprehensive error handling
4. Add colored output for better UX
5. Document required and optional environment variables
6. Update this README with usage instructions