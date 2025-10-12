# N8N Workflow Automation

Self-hosted workflow automation at `https://n8n.local`.

## Configuration

**Container**: `n8nio/n8n:latest`
**Database**: PostgreSQL 16 (dedicated container, Pi-optimized)
**Authentication**: HTTP Basic Auth (required)
**Resource Limits**: 512MB RAM, 1 CPU (n8n) + 256MB RAM, 0.5 CPU (PostgreSQL)

## Key Settings

**Raspberry Pi Optimizations**:
- PostgreSQL tuned for 8GB Pi: 64MB shared buffers, 256MB cache
- Reduced memory footprint: n8n 512MB, PostgreSQL 256MB
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

**Access**: Login at `https://n8n.local` with configured credentials.

## Migration from SQLite

If migrating from an existing SQLite setup:

1. **Stop the current n8n stack**:
   ```bash
   docker compose down
   ```

2. **Backup existing SQLite database** (if it exists):
   ```bash
   cp ./data/n8n/n8n.sqlite ./data/n8n/n8n.sqlite.backup
   ```

3. **Update environment variables** as described above

4. **Start the new stack** with PostgreSQL:
   ```bash
   docker compose up -d
   ```

5. **For data migration** (optional):
   - N8N will start fresh with PostgreSQL
   - To migrate workflows/credentials from SQLite, export them from the old instance and import to the new one via the web interface
   - Or use N8N's CLI tools for bulk migration if needed

**Note**: The PostgreSQL setup provides better performance and reliability for production use.