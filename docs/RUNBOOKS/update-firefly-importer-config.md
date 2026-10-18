# Update the Firefly importer config

**When:** a bank-data provider account is added, renamed or remapped, or an import setting changes.
**Preconditions:** SSH to the Pi. The config is the external Swarm config `firefly_importer_config`, mounted read-only in `firefly_importer` (`/var/www/html/import/config.json`) and `firefly_scheduler` (`/etc/firefly/importer.json`). A local copy lives (gitignored) in `services/firefly/config/config.json`.

## Steps
1. Create the Firefly asset account first (one per provider account and currency) and note its id.
2. Edit `accounts` (`"<provider id>": <Firefly id>`) in the local copy, then copy it to the Pi: `scp services/firefly/config/config.json pi@pi.local:/tmp/imp.json`.
3. On the Pi, swap the config (Swarm configs are immutable; detach, recreate, reattach):
   ```bash
   for svc in firefly_importer firefly_scheduler; do docker service update -q --config-rm firefly_importer_config "$svc"; done
   docker config rm firefly_importer_config && docker config create firefly_importer_config /tmp/imp.json && rm /tmp/imp.json
   docker service update -q --config-add source=firefly_importer_config,target=/var/www/html/import/config.json,mode=0444 firefly_importer
   docker service update -q --config-add source=firefly_importer_config,target=/etc/firefly/importer.json,mode=0444 firefly_scheduler
   ```

## Verify
`docker exec $(docker ps -qf label=com.docker.swarm.service.name=firefly_importer) cat /var/www/html/import/config.json | jq .accounts` shows the new mapping; the next auto-import logs `Exit code is SUCCESS`.

## Rollback
Repeat with the previous file.

**Last verified:** 2026-10-18 by Claude Code (importer only; scheduler mount is new in this release)
