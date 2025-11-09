# N8N Workflow Automation

Self-hosted workflow automation at `https://n8n.home`.

## Configuration

**Container**: `n8nio/n8n:latest`
**Database**: PostgreSQL 16 (dedicated container, Pi-optimized)
**Authentication**: HTTP Basic Auth (required)

## Key Settings

**Raspberry Pi Optimizations**:
- PostgreSQL tuned for 8GB Pi: 64MB shared buffers, 256MB cache
- Conservative connection limits (20 max connections)
- Optimized WAL and checkpoint settings for SD card longevity

**Security**:
- HTTPS-only configuration (nginx handles SSL)
- Basic auth: username `admin`, password via env
- Secure cookies enabled
- PostgreSQL with scram-sha-256 authentication

**Performance**:
- Main process execution (Pi-optimized)
- 7-day data retention with auto-pruning
- Non-root user execution
- Dedicated PostgreSQL database for better performance

**Network**: Access only via nginx proxy (no direct ports)

## Environment Setup

Copy `.env.example` to `.env` and set:
- `N8N_BASIC_AUTH_PASSWORD` (required - use strong password)
- `POSTGRES_PASSWORD` (required - use strong database password)
- Optional: `POSTGRES_USER`, `POSTGRES_DB` (defaults: n8n, n8n)
- Optional: paths and timezone

## Deployment

Requires [infrastructure stack](../../infra) running first.

1. Deploy via Portainer pointing to:

- Repository: `https://github.com/giocaizzi/rp5-homeserver`
- Container path: `services/n8n/docker-compose.yml`
- **Deploy Mode**: Select "Swarm" (not "Standalone")
Set environment variables in Portainer Stack → Environment Variables section.

2. Add `n8n.home` to your local `/etc/hosts`

3. Login at `https://n8n.home` with configured credentials.