# Firefly III Personal Finance Manager

Self-hosted personal finance manager at `https://firefly.local` with data importer at `https://firefly-importer.local`.

## Configuration

**Containers**: 
- `fireflyiii/core:latest` - Main application
- `mariadb:lts` - Database (dedicated container)
- `fireflyiii/data-importer:latest` - Data import tool
- `alpine` - Cron job scheduler

**Authentication**: Built-in user registration & authentication
**Resource Limits**: 512MB RAM, 1 CPU (app) + 512MB RAM, 0.5 CPU (database)

## Key Settings

**Raspberry Pi Optimizations**:
- Conservative memory limits: app 512MB, database 512MB, importer 256MB, cron 64MB
- Swap-aware configuration for 8GB Pi
- Optimized resource reservations
- JSON logging with rotation

**Security**:
- HTTPS-only via nginx proxy
- Trusted proxy configuration for proper IP handling
- No-new-privileges security option
- Secure database with random root password
- Secret tokens for cron and importer

**Performance**:
- Dedicated MariaDB database for optimal performance
- Health checks on all critical services
- Automatic daily cron job for recurring transactions
- Data importer for bank statement imports

**Network**: Access via nginx proxy (no direct ports exposed)

## Environment Setup

**See `.env.example` for complete list of variables.**

Set environment variables in Portainer Stack → Environment Variables section.

### Minimal Required Setup

```bash
# Application encryption key (base64, 32 chars)
APP_KEY=<generate-unique-value>

# Database password
DB_PASSWORD=<strong-random-password>

# Cron token (exactly 32 chars)
STATIC_CRON_TOKEN=<generate-32-char-token>

# OAuth Client ID (leave empty initially, set after first login)
FIREFLY_CLIENT_ID=
```

### Generate Secure Tokens

```bash
# APP_KEY
head /dev/urandom | LC_ALL=C tr -dc 'A-Za-z0-9' | head -c 32 | base64

# STATIC_CRON_TOKEN (exactly 32 characters)
head /dev/urandom | LC_ALL=C tr -dc 'A-Za-z0-9' | head -c 32

# DB_PASSWORD
openssl rand -base64 32
```

## Deployment

Requires [infrastructure stack](../../infra) running first.

Deploy via Portainer using the remote repository feature.

**Nginx Configuration**: Firefly III is accessible at:
- Main app: `https://firefly.local`
- Data Importer: `https://firefly-importer.local`

The nginx configuration has been added to `/infra/nginx/nginx.conf`.

## First Time Setup

1. **Generate required tokens** using commands above

2. **Set environment variables** in Portainer:
   - Set `APP_KEY`, `DB_PASSWORD`, `STATIC_CRON_TOKEN`
   - Leave `FIREFLY_CLIENT_ID` empty initially

3. **Deploy the stack** in Portainer

4. **Register first user**:
   - Navigate to `https://firefly.local`
   - Create your account (first user becomes admin)

5. **Generate OAuth Client ID** for data importer:
   - Login to Firefly III
   - Go to Profile → OAuth → "Create New Personal Access Client"
   - Name: "Data Importer"
   - Copy the Client ID
   - Update `FIREFLY_CLIENT_ID` in Portainer environment variables
   - Restart the stack

6. **Access Data Importer**:
   - Navigate to `https://firefly-importer.local`
   - When prompted for Firefly III URL, use: `http://app:8080`
   - Provide the Client ID generated in step 5

## Cron Jobs

Automated daily tasks run at 3:00 AM UTC:
- Process recurring transactions
- Execute auto-budgets
- Clear cache

The cron job uses `STATIC_CRON_TOKEN` for secure API access.

## Data Import

The Data Importer supports:
- CSV files
- Bank statement imports
- Automated imports via API
- Spectre/Salt Edge integration
- Nordigen (GoCardless) integration

Access at `https://firefly-importer.local` with the OAuth credentials.

## Backup

Important data locations:
- Database: MariaDB volume `firefly_db`
- Uploads: Volume `firefly_upload`

Include both volumes in your backup strategy.
