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

**Network**: Access via nginx proxy (no direct ports exposed)

## Environment Setup

**See `.env.example` for complete list of variables.**

Set environment variables in Portainer Stack → Environment Variables section.


## Deployment

Requires [infrastructure stack](../../infra) running first.

Deploy via Portainer using the remote repository feature.

**Important**: Ensure all required environment variables are set before deployment.

**Nginx Configuration**: Firefly III is accessible at:
- Main app: `https://firefly.local`
- Data Importer: `https://firefly-importer.local`

The nginx configuration has been added to `/infra/nginx/nginx.conf`.

### Deployment Steps:

1. **Clean up any previous failed deployments:**
   ```bash
   # Remove orphaned containers
   ssh giorgiocaizzi@pi.local "docker stop firefly_app firefly_db firefly_importer firefly_cron 2>/dev/null; docker rm firefly_app firefly_db firefly_importer firefly_cron 2>/dev/null || true"
   
   # Remove old volumes to ensure fresh database initialization
   ssh giorgiocaizzi@pi.local "docker volume rm firefly_firefly_db firefly_firefly_upload 2>/dev/null || true"
   ```

2. **Deploy via Portainer** pointing to:
   - Repository: `https://github.com/giocaizzi/rp5-homeserver`
   - Container path: `services/firefly/docker-compose.yml`

3. **Set required environment variables** in Portainer Stack → Environment Variables:
   ```bash
   APP_KEY=<generate-32-char-base64-key>
   DB_PASSWORD=<strong-password>
   STATIC_CRON_TOKEN=<32-character-token>
   FIREFLY_CLIENT_ID=1
   ```

4. **Monitor deployment progress** (expected timing):
   - Database initialization: ~60-90 seconds
   - App startup & migrations: ~120-180 seconds
   - Total deployment time: ~3-5 minutes

5. **Verify successful deployment:**
   ```bash
   # Check all containers are healthy
   ssh giorgiocaizzi@pi.local "docker ps | grep firefly"
   ```

6. **Access and setup**:
   - Navigate to `https://firefly.local`
   - Create your first user account

### Troubleshooting:

**Deployment fails in Portainer:**
1. **First step: Always clean up volumes** from previous failed attempts
2. Check that all required environment variables are set correctly
3. Ensure infrastructure stack is running (`rp5_public` network must exist)
4. Monitor container logs in Portainer for specific errors

**Common Issues:**
- **"Access denied for user 'firefly'"**: Old database volume exists, clean up volumes first
- **Portainer deployment timeout**: Expected on first deployment (3-5 minutes), let it complete
- **App health check fails**: Check app logs for database connection errors
- **Containers start then stop**: Usually database authentication issues from dirty volumes

**Timing Expectations:**
- **Database healthcheck**: 60-90 seconds for fresh initialization
- **App healthcheck**: 120-180 seconds (includes migrations)  
- **Total deployment**: 3-5 minutes on Raspberry Pi
- **Portainer timeout**: ~10-15 minutes (should not be reached)

**Performance Notes for Raspberry Pi:**
- Database initialization slower on ARM architecture
- Memory limits may cause swap usage (normal)
- First-time deployment takes longer due to image pulls and volume initialization


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
   - Redirect URL: `https://firefly-importer.local/callback`
   - UNCHECK "Confidential"
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
- **Lunch Flow integration** - Connect to your banks via [Lunch Flow](https://www.lunchflow.app/)

### Lunch Flow Setup

1. Sign up at [https://www.lunchflow.app/](https://www.lunchflow.app/)
2. Create connections to your bank accounts
3. In Lunch Flow dashboard: **Destinations** → **Add Destination** → **API** → **Firefly III**
4. Copy the generated API key
5. Set `LUNCH_FLOW_API_KEY` environment variable in Portainer
6. Restart the stack

Access at `https://firefly-importer.local` with the OAuth credentials.

## Backup

Important data locations:
- Database: MariaDB volume `firefly_db`
- Uploads: Volume `firefly_upload`

Include both volumes in your backup strategy.
