# 💰 Firefly III

> Personal finance manager with data importer and mobile frontend

**URLs**:
- Main app: `https://firefly.home`
- Data Importer: `https://firefly-importer.home`
- Pico (mobile): `https://firefly-pico.home`

---

## 🚀 Quick Start

1. Create secrets (see below)
2. Deploy via Portainer → Swarm mode
3. Register first user at `https://firefly.home`
4. Generate OAuth client for Data Importer

---

## 📦 Architecture

| Container | Image | Purpose |
|-----------|-------|---------|
| firefly-db | `mariadb:lts` | Main database |
| firefly-app | `fireflyiii/core:latest` | Finance app |
| firefly-importer | `fireflyiii/data-importer:latest` | Bank imports |
| firefly-pico-db | `postgres:16-alpine` | Pico database |
| firefly-pico | `cioraneanu/firefly-pico:latest` | Mobile frontend |
| firefly-cron | `alpine` | Scheduled jobs |

---

## 🔐 Secrets

| Secret | Generate |
|--------|----------|
| `firefly_app_key` | `echo "base64:$(openssl rand -base64 32)" \| docker secret create firefly_app_key -` |
| `firefly_db_password` | `openssl rand -base64 32 \| docker secret create firefly_db_password -` |
| `firefly_static_cron_token` | `openssl rand -hex 32 \| docker secret create firefly_static_cron_token -` |
| `firefly_auto_import_secret` | `openssl rand -hex 16 \| docker secret create firefly_auto_import_secret -` |
| `firefly_pico_db_password` | `openssl rand -base64 32 \| docker secret create firefly_pico_db_password -` |

**After deployment** (from Firefly UI):
| Secret | Source |
|--------|--------|
| `firefly_client_id` | Profile → OAuth → Create Personal Access Client |
| `firefly_access_token` | Profile → OAuth → Personal Access Tokens |
| `firefly_lunch_flow_api_key` | External: [lunchflow.app](https://www.lunchflow.app/) |

---

## 📖 Initial Setup

### 1. First User Registration

Navigate to `https://firefly.home` and create your account (first user = admin).

### 2. OAuth Client for Data Importer

1. Login to Firefly III
2. Profile → OAuth → **Create New Personal Access Client**
3. Settings:
   - Name: `Data Importer`
   - Redirect URL: `https://firefly-importer.home/callback`
   - **Uncheck** "Confidential"
4. Copy Client ID → create secret:
   ```bash
   echo -n "YOUR_CLIENT_ID" | docker secret create firefly_client_id -
   ```
5. Restart stack in Portainer

### 3. Access Data Importer

- Navigate to `https://firefly-importer.home`
- Firefly III URL: `http://firefly-app:8080` (internal)
- Enter Client ID from step 2

---

## 📱 Pico Mobile Frontend

Lightweight mobile interface connecting to Firefly III API.

### Setup

1. Generate Personal Access Token in Firefly III:
   - Profile → OAuth → Personal Access Tokens → Create
   - Select all scopes

2. Configure Pico:
   - Navigate to `https://firefly-pico.home`
   - Settings → App Config
   - Paste the Personal Access Token
   - Leave "Pico Backend URL" as default

### Architecture Note

Two-layer communication:
```
Browser → Pico Frontend (https://firefly-pico.home)
                ↓
        Pico Backend → Firefly API (http://firefly-app:8080)
```

---

## 🔄 Data Importer & Lunch Flow

### Lunch Flow Integration

1. Sign up at [lunchflow.app](https://www.lunchflow.app/)
2. Connect your bank accounts
3. Destinations → Add Destination → API → Firefly III
4. Copy API key → create secret:
   ```bash
   echo -n "YOUR_API_KEY" | docker secret create firefly_lunch_flow_api_key -
   ```

### Automated Imports

Imports run from config files placed in the importer container.

1. **Create config manually first**:
   - Access `https://firefly-importer.home`
   - Configure import settings
   - Download JSON config

2. **Deploy config to container**:
   ```bash
   scp config.json pi@pi.local:/tmp/
   ssh pi@pi.local "docker cp /tmp/config.json \$(docker ps -qf 'label=com.docker.swarm.service.name=firefly_importer'):/import/config.json"
   ```

3. **Add Personal Access Token to config**:
   - Edit config.json: `"access_token": "eyJ0eXAi..."`

See [Data Importer docs](https://docs.firefly-iii.org/how-to/data-importer/import/automated/) for config reference.

---

## ⏰ Cron Jobs

| Time (UTC) | Job | Purpose |
|------------|-----|---------|
| 3:00 AM | Firefly cron | Recurring transactions, auto-budgets, exchange rates |
| 2:40 AM | Auto-import | Import from Lunch Flow via config.json |

Both run in the `firefly-cron` Alpine container.

---

## 💾 Volumes

| Volume | Purpose |
|--------|---------|
| `firefly_db` | MariaDB data |
| `firefly_upload` | User uploads |
| `firefly_pico_db` | Pico PostgreSQL |


