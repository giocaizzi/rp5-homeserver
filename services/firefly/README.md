# 💰 Firefly III

> Personal finance manager with data importer

**URLs**:
- Main app: `https://firefly.home`
- Data Importer: `https://firefly-importer.home`

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
| firefly-cron | `alpine` | Scheduled jobs |

---

## 🔐 Secrets

| Secret | Generate |
|--------|----------|
| `firefly_app_key` | `echo "base64:$(openssl rand -base64 32)" \| docker secret create firefly_app_key -` |
| `firefly_db_password` | `openssl rand -base64 32 \| docker secret create firefly_db_password -` |
| `firefly_static_cron_token` | `openssl rand -hex 32 \| docker secret create firefly_static_cron_token -` |
| `firefly_auto_import_secret` | `openssl rand -hex 16 \| docker secret create firefly_auto_import_secret -` |

**After deployment** (from Firefly UI):
| Secret | Source |
|--------|--------|
| `firefly_client_id` | Profile → OAuth → Create Personal Access Client |
| `firefly_access_token` | Profile → OAuth → Personal Access Tokens |
| `firefly_lunch_flow_api_key` | External: [lunchflow.app](https://www.lunchflow.app/) |

### Rotating `firefly_access_token`

A Personal Access Token is a Laravel Passport JWT signed by `storage/oauth-private.key`. Generating a new token in the UI does **not** invalidate the previous one — but losing the key pair does (every JWT signed by the old private key fails verification, all at once). The `firefly_storage` volume persists those keys across container restarts; rotation is only needed when you want to revoke an existing token or when the keys were regenerated (e.g. by a deploy that predated `firefly_storage`).

Naive `docker secret rm` + `create` crash-loops the scheduler container, because its startup script `cat`s the secret. Detach first, then swap, then reattach:

```bash
# 1. Generate a new token in the Firefly UI (Profile → OAuth → Personal Access Tokens)
#    and place it in services/firefly/secrets/firefly_access_token.txt (gitignored).

# 2. Rotate the Swarm secret in three steps from the Pi.
NEW_TOKEN=$(cat services/firefly/secrets/firefly_access_token.txt)
ssh pi@pi.local "TOKEN=$(printf %q "$NEW_TOKEN") bash -s" <<'EOF'
set -euo pipefail
docker service update --secret-rm firefly_access_token firefly_scheduler >/dev/null
docker secret rm firefly_access_token >/dev/null
printf %s "$TOKEN" | docker secret create firefly_access_token - >/dev/null
docker service update \
  --secret-add source=firefly_access_token,target=firefly_access_token \
  firefly_scheduler >/dev/null
EOF

# 3. Confirm
ssh pi@pi.local '
  SCHED=$(docker ps -qf "label=com.docker.swarm.service.name=firefly_scheduler" | head -1)
  docker exec "$SCHED" head -c 30 /run/secrets/firefly_access_token; echo
'
```

The scheduler will briefly fail one task while the secret is detached — Swarm reschedules within ~5 s as soon as the new secret is attached.

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

| Volume | Mount | Purpose |
|--------|-------|---------|
| `firefly_db` | `/var/lib/mysql` | MariaDB data |
| `firefly_storage` | `/var/www/html/storage` | Laravel storage tree — **persists `oauth-{public,private}.key`** so Personal Access Tokens survive container recreate. Also keeps `framework/`, `logs/`, `app/`. |
| `firefly_upload` | `/var/www/html/storage/upload` | User attachments. Nested-mounted inside `firefly_storage` so uploads are isolated from the rest of `storage/` for backups. |

> Without `firefly_storage`, every container recreate regenerates the OAuth signing keys, invalidating every existing Personal Access Token at once. See [Rotating `firefly_access_token`](#rotating-firefly_access_token) for recovery.

### First deploy of `firefly_storage` (one-time)

When the volume is first created, Docker copies `storage/*` from the image — which has no OAuth keys (they are generated at runtime). Passport then writes fresh keys into the empty volume, **invalidating the existing PAT**. Two paths:

1. **Easy path — rotate the PAT once after deploy.** Deploy normally, then follow [Rotating `firefly_access_token`](#rotating-firefly_access_token). Every future redeploy is safe.

2. **Preserve current PAT — pre-seed the volume.** Before the redeploy, copy the running keys into a fresh `firefly_firefly_storage` volume:

   ```bash
   ssh pi@pi.local '
     APP=$(docker ps -qf "label=com.docker.swarm.service.name=firefly_app" | head -1)
     docker cp "$APP":/var/www/html/storage/oauth-private.key /tmp/p.key
     docker cp "$APP":/var/www/html/storage/oauth-public.key  /tmp/P.key
     docker volume create firefly_firefly_storage
     docker run --rm \
       -v firefly_firefly_storage:/dst -v /tmp:/src alpine sh -c "
         cp /src/p.key /dst/oauth-private.key &&
         cp /src/P.key /dst/oauth-public.key &&
         chown 33:33 /dst/oauth-*.key &&
         chmod 600  /dst/oauth-*.key
       "
     shred -u /tmp/p.key /tmp/P.key
   '
   ```

   Then deploy. Docker sees the volume is non-empty and skips the image-copy, so the keys you seeded stay — the existing PAT keeps working.


