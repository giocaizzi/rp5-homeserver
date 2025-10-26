# Infrastructure Stack

> *Deploy this stack first* - other services depend on the networks created here.

## Network Architecture

**Created Networks:**
- `rp5_public` - Shared network for nginx ↔ service communication
- `rp5_infra` - Internal infrastructure network

**Service Integration:**
Services join `rp5_public` network to enable nginx routing without exposing ports directly.

```
Internet → Nginx (rp5_public) → Services (rp5_public + private networks)
```

## Services

**Nginx Reverse Proxy** (`nginx:alpine`)
- SSL termination and routing for all services
- Rate limiting and security headers
- WebSocket support for Portainer/N8N

**Portainer EE** (`portainer/portainer-ee:latest`)
- Docker management UI at `https://portainer.local`
- Business Edition with advanced features
- Resource limited (256MB RAM max)
- Read-only Docker socket access

> Using Business Edition for enhanced stack management capabilities.
> Get a free license (less than 3 nodes) at [Portainer](https://www.portainer.io/).

**Cloudflare Tunnel** (`cloudflare/cloudflared:latest`)
- Secure external access without port forwarding
- Requires `CLOUDFLARED_TOKEN` environment variable

**Netdata Monitoring** (`netdata/netdata:latest`)
- Real-time system monitoring at `https://netdata.local`
- Performance metrics, alerts, and dashboards
- Integrated with host system via bind mounts

**Backrest** (`garethgeorge/backrest:latest`)
- Web UI for restic backups at `https://backrest.local`
- Automated incremental backups to Google Cloud Storage
- Backs up user home directory and Docker volumes
- Configurable retention policy via web interface
- Real-time backup monitoring and notifications

**Homepage** (`ghcr.io/gethomepage/homepage:latest`)
- Modern application dashboard at `https://homepage.local`
- Centralized access to all services
- Real-time system stats and Docker container monitoring
- Customizable widgets and service status indicators

## Portainer API Key Setup

To enable Portainer widget integration:

1. Access Portainer at `https://portainer.local`
2. Navigate to User account → API keys
3. Generate a new API key
4. Replace `ptr_xxxxxxxxxxxxxxxxxxxxx` in `services.yaml` with your actual API key
5. Restart homepage container: `docker compose restart homepage`

## Widget Features

With API integration enabled, the Portainer widget will show:
- Container count by status
- Stack information
- Resource usage

## Security Note

The API key provides read-only access to container information. Store securely and rotate periodically.

## Volumes & Data

**Named Volumes:**
- `portainer_data` - Portainer configuration and stacks
- `netdata_cache` - Monitoring metrics cache
- `netdata_config` - Custom monitoring configuration
- `netdata_lib` - Monitoring runtime data
- `backrest_data` - Backup metadata and state
- `backrest_config` - Backup plans and repository config
- `backrest_cache` - Restic cache for performance

> Homepage uses local config files from `./homepage/` directory.

## Configuration

See [`.env.example`](./.env.example) for all environment variables.

## Backup Setup

**Prerequisites:**
1. Google Cloud Storage bucket with service account access
2. Create GCP service account key:
   ```bash
   # Download the JSON key file from Google Cloud Console
   # Save as backup/secrets/gcp_service_account.json
   ```
3. Configure bucket name in `.env` file:
   ```bash
   GCP_SERVICE_ACCOUNT_FILE=./backup/secrets/gcp_service_account.json
   ```

**Configure via Web UI:**
1. Start the stack: `docker compose up -d`
2. Access Backrest at `https://backrest.local`
3. Create repository pointing to GCS bucket
4. Set up backup plans with schedules and retention policies

See [Backup Documentation](../docs/backup.md) for complete setup guide.

## Nginx Post-Setup

### Generate certificates locally

SSL Certificates must be present in `./nginx/ssl` before starting the stack.

See [SSL Generation Instructions](../docs/setup.md#1-infrastructure-stack).

### Update hostsfile

In order to pass `nginx` hostname resolution, add to your local `/etc/hosts` file:

```
192.168.x.x portainer.local netdata.local backrest.local homepage.local <other_service>.local
```
