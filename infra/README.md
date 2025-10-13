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

**Restic Backup** (`restic/restic:latest`)
- Automated incremental backups to Google Cloud Storage
- Backs up `/home/giorgiocaizzi` and Docker volumes
- Configurable retention policy (7 daily, 4 weekly)
- Secure secrets management via Docker secrets

## Volumes & Data

**Named Volumes:**
- `portainer_data` - Portainer configuration and stacks
- `netdata_cache` - Monitoring metrics cache
- `netdata_config` - Custom monitoring configuration
- `netdata_lib` - Monitoring runtime data
- `restic_cache` - Backup repository cache for performance

## Configuration

See [`.env.example`](./.env.example) for all environment variables.

## Backup Setup

**Prerequisites:**
1. Google Cloud Storage bucket with service account access
2. Create secrets files:
   ```bash
   # Create restic repository password
   echo "your-strong-restic-password" > backup/secrets/restic_password.txt
   
   # Create GCP service account key (get from Google Cloud Console)
   # Download the JSON key file and save as backup/secrets/gcp_service_account.json
   ```
3. Configure bucket name in `.env` file

**Automated Backup (Recommended):**
```bash
# SSH to Pi and set up daily backup at 2 AM
ssh pi@pi.local
sudo crontab -e
# Add: 0 2 * * * cd /home/pi/rp5-homeserver/infra && ./backup/backup.sh >> /var/log/restic-backup.log 2>&1
```

**Manual Backup:**
```bash
ssh pi@pi.local "cd ~/rp5-homeserver/infra && ./backup/backup.sh"
```

**Restore Files:**
```bash
# List snapshots
ssh pi@pi.local "cd ~/rp5-homeserver/infra && ./backup/restore.sh --list"

# Restore specific path
ssh pi@pi.local "cd ~/rp5-homeserver/infra && ./backup/restore.sh /backup/home/giorgiocaizzi/Documents /tmp/restore"
```

## Nginx Post-Setup

### Generate certificates locally

SSL Certificates must be present in `./nginx/ssl` before starting the stack.

See [SSL Generation Instructions](../docs/setup.md#1-infrastructure-stack).

### Update hostsfile

In order to pass `nginx` hostname resolution, add to your local `/etc/hosts` file:

```
192.168.x.x portainer.local netdata.local <other_service>.local
```
