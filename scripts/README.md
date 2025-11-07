# Scripts

Automation scripts for managing the Raspberry Pi home server.

## Usage

All scripts require environment variables for configuration. No sensitive defaults are provided.

### sync_infra.sh

Syncs the local infra directory to the Raspberry Pi and restarts all infra services.

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
2. Fixes ownership permissions on remote infra directory
3. Syncs local infra directory to Pi using rsync
4. Stops current Docker Compose services
5. Optionally pulls latest Docker images (with `--pull` flag)
6. Starts services with new configuration
7. Shows final service status

## Adding New Scripts

When adding new scripts to this directory:

1. Use environment variables for all configuration
2. Provide no sensitive defaults
3. Include comprehensive error handling
4. Add colored output for better UX
5. Document required and optional environment variables
6. Update this README with usage instructions