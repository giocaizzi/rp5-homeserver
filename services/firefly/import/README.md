# Import Configuration Directory

This directory is mounted into the Data Importer container as `/import` for automated imports.

## About This Directory

- **Location on Pi**: `/home/pi/rp5-homeserver/services/firefly/import/`
- **Mount in container**: `/import` (read-only for importer)
- **Git tracking**: Files in this directory are **ignored by git** (except this README)

## Configuration Files

### `config.json` (required for automated imports)

The JSON configuration file that defines how automated imports should run. This file:
- Contains your import settings (accounts, mappings, date ranges)
- Is NOT tracked in git (may contain sensitive IDs)
- Must be manually copied to the Pi

**How to create and deploy**:

1. **Generate config via UI**:
   - Access `https://firefly-importer.local`
   - Run a manual import with desired settings
   - Download the configuration file at the end

2. **Deploy to Pi**:
   ```bash
   # Copy from your downloads to Pi
   scp ~/Downloads/your-config.json pi@pi.local:/home/pi/rp5-homeserver/services/firefly/import/config.json
   ```

3. **Redeploy stack** in Portainer to ensure the mount picks up the new file

**See**: [Official JSON configuration reference](https://docs.firefly-iii.org/references/data-importer/json/)

## How It Works with Portainer Remote Deployment

Portainer clones the git repo to the Pi at stack deployment time. The relative mount `./import:/import` in `docker-compose.yml` works because:

1. Portainer clones repo → `/home/pi/rp5-homeserver/`
2. Docker Compose resolves `./import` → `/home/pi/rp5-homeserver/services/firefly/import/`
3. Container mounts this directory at `/import`

Your `config.json` persists on the Pi filesystem across Portainer redeployments since it's not tracked in git.

## Automated Import Schedule

The cron container runs automated imports at **2:40 AM UTC** daily using:
```
http://importer:8080/autoimport?directory=/import&secret=$AUTO_IMPORT_SECRET
```

This endpoint reads `config.json` from the mounted `/import` directory.
