# N8N Workflow Automation

Self-hosted workflow automation at `https://n8n.local`.

## Configuration

**Container**: `n8nio/n8n:latest`
**Database**: SQLite (local file)
**Authentication**: HTTP Basic Auth (required)
**Resource Limits**: 1GB RAM, 1 CPU core

## Key Settings

**Security**:
- HTTPS-only configuration (nginx handles SSL)
- Basic auth: username `admin`, password via env
- Secure cookies enabled

**Performance**:
- Main process execution (Pi-optimized)
- 7-day data retention with auto-pruning
- Non-root user execution

**Network**: Access only via nginx proxy (no direct ports)

## Environment Setup

Copy `.env.example` to `.env` and set:
- `N8N_BASIC_AUTH_PASSWORD` (required - use strong password)
- Optional: paths and timezone

## Deployment

Requires [infrastructure stack](../../infra) running first.

**Access**: Login at `https://n8n.local` with configured credentials.