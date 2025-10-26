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
   ssh pi@pi.local  "docker stop firefly_app firefly_db firefly_importer firefly_cron 2>/dev/null; docker rm firefly_app firefly_db firefly_importer firefly_cron 2>/dev/null || true"
   
   # Remove old volumes to ensure fresh database initialization
   ssh pi@pi.local  "docker volume rm firefly_firefly_db firefly_firefly_upload 2>/dev/null || true"
   ```

2. **Deploy via Portainer** pointing to:
   - Repository: `https://github.com/giocaizzi/rp5-homeserver`
   - Container path: `services/firefly/docker-compose.yml`

3. **Set required environment variables** in Portainer Stack → Environment Variables:
   ```bash
   APP_KEY=<generate-32-char-base64-key>
   DB_PASSWORD=<strong-password>
   STATIC_CRON_TOKEN=<32-character-token>
   AUTO_IMPORT_SECRET=<16-character-secret>
   FIREFLY_CLIENT_ID=1
   LUNCH_FLOW_API_KEY=<lunch-flow-api-key>
   ```
   
   Generate tokens:
   ```bash
   # APP_KEY (base64 encoded 32 characters)
   openssl rand -base64 32
   
   # STATIC_CRON_TOKEN and AUTO_IMPORT_SECRET
   openssl rand -hex 16
   ```

4. **Monitor deployment progress** (expected timing):
   - Database initialization: ~60-90 seconds
   - App startup & migrations: ~120-180 seconds
   - Total deployment time: ~3-5 minutes

5. **Verify successful deployment:**
   ```bash
   # Check all containers are healthy
   ssh pi@pi.local  "docker ps | grep firefly"
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
   - Set `APP_KEY`, `DB_PASSWORD`, `STATIC_CRON_TOKEN`, `AUTO_IMPORT_SECRET`
   - Set `FIREFLY_CLIENT_ID=1` initially

3. **Deploy the stack** in Portainer

4. **Register first user**:
   - Navigate to `https://firefly.local`
   - Create your account (first user becomes admin)

5. **Generate OAuth Client ID for Data Importer**:
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
   - The system will use OAuth flow for authentication


## Cron Jobs

Following the [official automated import documentation](https://docs.firefly-iii.org/how-to/data-importer/import/automated/), automated tasks run daily:

- **3:00 AM UTC**: **Firefly III maintenance cron** (`/api/v1/cron/[token]`)
  - Recurring transactions: Creates scheduled recurring transactions
  - Auto-budgets: Automatically allocates budget amounts based on rules
  - Exchange rates: Updates currency exchange rates from external providers
  - Bill notifications: Sends alerts for upcoming or overdue bills

- **2:40 AM UTC**: **Data Importer autoimport** (`/autoimport?directory=/import&secret=[secret]`)
  - Imports new bank transactions from configured data providers (Lunch Flow, GoCardless, etc.)
  - Scans the `/import` directory for configuration files
  - Uses personal access token authentication with Bearer header
  - Applies duplicate detection to prevent re-importing existing transactions

Both cron jobs run in the same Alpine container but serve completely different purposes: **internal Firefly maintenance** vs **external data import**.

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
3. Customize connection settings (under "X Accounts" → "Description" - **must not be empty**)
4. In Lunch Flow dashboard: **Destinations** → **Add Destination** → **API** → **Firefly III**
5. Copy the generated API key
6. Set `LUNCH_FLOW_API_KEY` environment variable in Portainer
7. Restart the stack

### Automated Lunch Flow Imports

Automated imports reuse a configuration you create manually first. See the [official documentation on automated imports](https://docs.firefly-iii.org/how-to/data-importer/import/automated/).

**Setup Process**:

1. **Create and test configuration manually**:
   - Access the importer at `https://firefly-importer.local`
   - Select "Lunch Flow" as import method
   - Configure:
     - Which bank accounts to import from
     - Which Firefly III accounts to import into
     - Date range (e.g., "last 30 days")
     - Data mapping preferences
   - Run the import to verify it works
   - At the end, **download the configuration file** (JSON)
   - See [JSON configuration file reference](https://docs.firefly-iii.org/references/data-importer/json/) for field details

2. **Deploy configuration to the container**:
   ```bash
   # Copy config directly to the running container (no volume mount needed)
   scp import/config.json giorgiocaizzi@pi.local:/tmp/config.json
   ssh giorgiocaizzi@pi.local "docker cp /tmp/config.json firefly_importer:/import/config.json"
   
   # Verify the file is in the container
   ssh giorgiocaizzi@pi.local "docker exec firefly_importer ls -la /import/"
   ```

   **Important**: Your config.json must include a valid personal access token for automated imports:
   
   a. **Generate personal access token**:
      - Login to Firefly III at `https://firefly.local`
      - Go to Profile → OAuth → Personal Access Tokens
      - Click "Create New Token"
      - Name: "Data Importer Automated"
      - Select all scopes (read/write)
      - Copy the generated token
   
   b. **Update config.json** with the token:
      - Edit your local `import/config.json`
      - Find the `"access_token": ""` field
      - Replace empty string with your token: `"access_token": "eyJ0eXAiOiJKV1QiLCJ..."`
      - Save and copy to container again

3. **Automated imports run daily at 2:40 AM UTC**:
   - Uses the configuration in `/import/config.json`
   - Connects to Lunch Flow with your API key
   - Imports new transactions based on the date range in config
   - Duplicate detection prevents re-importing existing transactions

**How it works with Portainer remote deployment**:
- No volume mount needed - config is copied directly to running container
- Uses `docker cp` to transfer config.json to `/import/config.json` in container
- Simpler, cleaner approach with no Portainer path dependencies
- Config persists in container until next redeploy (then just copy again)
- See `import/README.md` for details on the configuration file

**Important Notes**:
- Copy config after each stack redeploy using `docker cp`
- **Personal access token required**: Config must include valid `access_token` for automated imports
- Date ranges in config (e.g., "last 30 days") are evaluated at import time
- The `AUTO_IMPORT_SECRET` must be set in environment variables
- Config files are NOT tracked in git (contain sensitive account IDs, mappings, and tokens)

Access at `https://firefly-importer.local` with the OAuth credentials.

## Backup

Important data locations:
- Database: MariaDB volume `firefly_db`
- Uploads: Volume `firefly_upload`
- Import configurations: `services/firefly/import/` (on Pi host filesystem)

Include volumes in your backup strategy. Back up import configs separately if needed.
