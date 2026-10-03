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

**Flags:** `--dry-run`, `--pull`, `--restart`, `--local`, `--help`

**Secrets:** without `--local`, the file-based infra secrets on the Pi are written from the
Secrets Manager project (`BWS_ACCESS_TOKEN` required, plus `bws` and `jq`; key =
`infra_<file stem>`). A file is rewritten only when its hash differs, with mode `600`.
`secrets/` is never rsynced, so the workstation holds no secret files.

`--local` runs directly on the Pi (no SSH) — used by the `deploy-infra.yml`
self-hosted runner. It needs no Secrets Manager access and leaves the on-Pi
secrets untouched (`secrets/` is excluded from the `rsync --delete`).
`PI_SSH_USER` is still required (it derives `PI_INFRA_PATH`).

**Usage:**
```bash
# Basic usage (SSH from your workstation)
PI_SSH_USER=pi ./sync_infra.sh

# With image pull
PI_SSH_USER=pi ./sync_infra.sh --pull

# On the Pi itself (what CI runs)
PI_SSH_USER=pi ./sync_infra.sh --local

# Show help
./sync_infra.sh --help

# With custom host
PI_SSH_USER=pi PI_HOST=192.168.1.100 ./sync_infra.sh
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

### setup_pi_runner.sh

Installs and registers a self-hosted GitHub Actions runner **on the Pi** (label
`rp5`) as a systemd service, so `deploy-infra.yml` can run `sync_infra.sh
--local`. Run it on the Pi, as the user owning the deploy path (and in the
`docker` group).

**Required Environment Variables:**
- `GITHUB_REPO` - `owner/repo` (e.g. `giocaizzi/rp5-homeserver`)
- `RUNNER_TOKEN` - registration token from GitHub → Settings → Actions → Runners → New self-hosted runner

**Optional Environment Variables:**
- `RUNNER_LABELS` (default: `rp5`), `RUNNER_NAME`, `RUNNER_VERSION`, `RUNNER_DIR`

**Usage:**
```bash
GITHUB_REPO=giocaizzi/rp5-homeserver RUNNER_TOKEN=<token> ./setup_pi_runner.sh
```

Re-running is safe (re-registers with `--replace`). See [docs/gitops.md](../docs/gitops.md).

---

### create_secrets.sh

Syncs Docker Swarm external secrets for a service stack from the **Bitwarden Secrets Manager** project `rp5-homeserver` (single source of truth; no local secret files). Used for services deployed via Portainer Remote Stacks.

**Required Environment Variables:**
- `PI_SSH_USER` - SSH username for the Pi
- `BWS_ACCESS_TOKEN` - Secrets Manager machine-account token with read access to the project

**Optional Environment Variables:**
- `PI_HOST` - Pi hostname or IP (default: `pi.local`)
- `BWS_PROJECT` - Secrets Manager project name (default: `rp5-homeserver`)

**Requires:** `bws`, `jq`.

**Arguments:**
- `<stack>` - Stack name (e.g., `n8n`, `firefly`, `langfuse`, `observability`), or `--all`

**Usage:**
```bash
# Create secrets for n8n stack
BWS_ACCESS_TOKEN=<token> PI_SSH_USER=pi ./create_secrets.sh n8n

# Dry run - show what would be created
PI_SSH_USER=pi ./create_secrets.sh firefly --dry-run

# Also remove secrets on the Pi that the compose file no longer references
PI_SSH_USER=pi ./create_secrets.sh langfuse --prune

# Show help
./create_secrets.sh --help
```

**What it does:**
1. Parses external secrets from the stack's `docker-compose.yml`
2. Looks up each secret by name in the Secrets Manager project (loaded once, in memory only)
3. Creates or updates Docker Swarm secrets on the Pi via SSH, labelling each with a hash of its value (unchanged ones are skipped)
4. Follows naming convention: `<stack>_<secret_name>`

Secrets created before the `hash` label existed (e.g. by hand with `docker secret create`) always report "would update"; Docker secrets are immutable, so an in-use one is left untouched.

**Secret naming convention:**
| Stack | Secrets Manager key | Swarm Secret Name |
|-------|---------------------|-------------------|
| n8n | `n8n_postgres_password` | `n8n_postgres_password` |
| firefly | `firefly_app_key` | `firefly_app_key` |
| langfuse | `langfuse_salt` | `langfuse_salt` |

The key is the Swarm secret name. Add a new secret with `bws secret create <stack>_<name> "$(openssl rand -hex 32)" <project-id>`, then run the script. `infra/` secrets stay file-based (see AGENTS.md).

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