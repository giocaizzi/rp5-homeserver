# Infrastructure Stack

> *Deploy this stack first using Docker Swarm* - other services depend on the networks created here.

## Network Architecture

**Created Networks:**
- `rp5_public` - Shared overlay network for nginx ↔ service communication
- `rp5_infra` - Internal infrastructure overlay network

**Service Integration:**
Services join `rp5_public` overlay network to enable nginx routing without exposing ports directly.

```
Internet → Nginx (rp5_public) → Services (rp5_public + private overlay networks)
```

## Services

**Nginx Reverse Proxy** (`nginx:alpine`)
- SSL termination and routing for all services
- Rate limiting and security headers
- WebSocket support for Portainer/N8N

**Portainer EE** (`portainer/portainer-ee:latest`)
- Docker management UI at `https://portainer.home`
- Business Edition with advanced features
- Resource limited (256MB RAM max)
- Read-only Docker socket access

> Using Business Edition for enhanced stack management capabilities.
> Get a free license (less than 3 nodes) at [Portainer](https://www.portainer.io/).

**Cloudflare Tunnel** (`cloudflare/cloudflared:latest`)
- Secure external access without port forwarding
- Requires `CLOUDFLARED_TOKEN` environment variable

**Netdata Monitoring** (`netdata/netdata:latest`)
- Real-time system monitoring at `https://netdata.home`
- Performance metrics, alerts, and dashboards
- Integrated with host system via bind mounts

**Backrest** (`garethgeorge/backrest:latest`)
- Web UI for restic backups at `https://backrest.home`
- Automated incremental backups to Google Cloud Storage
- Backs up user home directory and Docker volumes
- Configurable retention policy via web interface
- Real-time backup monitoring and notifications

**Homepage** (`ghcr.io/gethomepage/homepage:latest`)
- Modern application dashboard at `https://homepage.home`
- Centralized access to all services
- Real-time system stats and Docker container monitoring
- Customizable widgets and service status indicators

## Portainer API Key Setup

To enable Portainer widget integration:

1. Access Portainer at `https://portainer.home`
2. Navigate to User account → API keys
3. Generate a new API key
4. Replace `ptr_xxxxxxxxxxxxxxxxxxxxx` in `services.yaml` with your actual API key
5. Restart homepage service: `docker service update --force infra_homepage`

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

### Docker Swarm Secrets

Sensitive configuration is managed via Docker Swarm secrets stored in `./secrets/`:

**Required secrets:**
- `ssl_cert` (`./secrets/cert.pem`) - SSL certificate
- `ssl_key` (`./secrets/key.pem`) - SSL private key  
- `cloudflared_token` (`./secrets/cloudflared_token.txt`) - Cloudflare tunnel token
- `gcp_service_account` (`./secrets/gcp_service_account.json`) - GCP service account for backups

**Service integration secrets:**
- `portainer_api_key` (`./secrets/portainer_api_key.txt`) - Portainer API access
- `backrest_admin_password` (`./secrets/backrest_admin_password.txt`) - Backrest web UI password  
- `firefly_api_token` (`./secrets/firefly_api_token.txt`) - Firefly III API access
- `adguard_password` (`./secrets/adguard_password.txt`) - AdGuard Home password
- `domain` (`./secrets/domain.txt`) - Primary domain name

## Backup Setup

**Prerequisites:**
1. Google Cloud Storage bucket with service account access
2. Create GCP service account key and save to `./secrets/gcp_service_account.json`
3. Set admin password in `./secrets/backrest_admin_password.txt`

**Configure via Web UI:**
1. Deploy the infrastructure stack: `docker stack deploy -c docker-compose.yml infra`
2. Access Backrest at `https://backrest.home`
3. Create repository pointing to GCS bucket
4. Set up backup plans with schedules and retention policies

See [Backup Documentation](../docs/backup.md) for complete setup guide.

## Nginx Post-Setup

### SSL Setup

SSL Certificates must be present as Docker Swarm secrets before starting the stack:

- `./secrets/cert.pem` - SSL certificate
- `./secrets/key.pem` - SSL private key

See [SSL Generation Instructions](../docs/setup.md#1-infrastructure-stack) for certificate generation.

### DNS Resolution Setup

For services to be accessible via `.home` domains (e.g., `portainer.home`, `netdata.home`), configure DNS resolution:

**Recommended**: Use AdGuard DNS rewrites for automatic network-wide resolution.

**Alternative**: Manually add entries to `/etc/hosts` on each client device.

See [DNS & Hostname Resolution](../docs/dns.md) for complete setup instructions.
