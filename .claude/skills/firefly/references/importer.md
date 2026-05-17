# Firefly III Data Importer

The Data Importer (`fireflyiii/data-importer:latest`, currently v2.3.2 on this stack) is a separate service that ingests **CSV files**, **Spectre** statements, **Nordigen/GoCardless** PSD2 feeds, **camt.053** XML, and **Lunch Flow** JSON pushes — then POSTs them through Firefly's API as ordinary transactions.

This stack runs it as service `firefly_importer`, container `firefly-importer`, internal URL `http://firefly-importer:8080`, public URL `https://firefly-importer.home` (LAN) / `https://firefly-importer.giocaizzi.xyz` (Cloudflare).

The two surfaces:

1. **UI flow** — uploads → preview → import. Used once to *produce* a JSON config you can rerun.
2. **Auto-import flow** — drop files + the saved config into `/var/www/html/import/` inside the container, then POST `/autoimport`. This is what the nightly cron and Lunch Flow integration use.

## OAuth setup (one-time, after a fresh deploy)

The importer needs a Firefly III **OAuth Personal Access Client** (different from a Personal Access Token).

1. Firefly UI → Profile → OAuth → **Create New Personal Access Client**.
   - Name: `Data Importer`
   - Redirect URL: `https://firefly-importer.home/callback`
   - **Uncheck** *Confidential*.
2. Copy the resulting **Client ID** (integer).
3. Create the Swarm secret:
   ```bash
   echo -n "<client_id>" | ssh giorgiocaizzi@pi.local 'docker secret create firefly_client_id -'
   ```
4. `docker service update --force firefly_importer` so the new secret mounts.
5. Visit `https://firefly-importer.home`, log in via Firefly when prompted; the importer stores its access token in its own session and is ready.

## Auto-import — what's wired up

The `firefly-scheduler` Alpine container has a cron entry that nightly POSTs:

```
POST /autoimport?directory=/var/www/html/import&secret=$AUTO_IMPORT_SECRET
Authorization: Bearer $FIREFLY_ACCESS_TOKEN
```

`AUTO_IMPORT_SECRET` is the `firefly_auto_import_secret` Swarm secret (gate so a random visitor can't trigger imports). `FIREFLY_ACCESS_TOKEN` is the Firefly Personal Access Token, used by the importer to call back into Firefly.

The endpoint iterates files in `/var/www/html/import/` (which is `firefly_upload` shared with the app). For each `*.json` config it finds, it imports the matching data file (`<name>.csv` or whatever the config references).

## Triggering an auto-import manually

The endpoint **requires** the bearer token; an empty body POST without it returns 401. The token lives in the scheduler's mounted secret:

```bash
ssh giorgiocaizzi@pi.local "
  SCHED=\$(docker ps --filter 'label=com.docker.swarm.service.name=firefly_scheduler' --format '{{.Names}}' | head -1)
  TOKEN=\$(docker exec \$SCHED cat /run/secrets/firefly_access_token)

  IMP=\$(docker ps --filter 'label=com.docker.swarm.service.name=firefly_importer' --format '{{.Names}}' | head -1)
  SECRET=\$(docker exec \$IMP cat /run/secrets/auto_import_secret)

  docker exec \$IMP curl -sS -X POST \
    -H 'Accept: application/json' \
    -H \"Authorization: Bearer \${TOKEN}\" \
    \"http://localhost:8080/autoimport?directory=/var/www/html/import&secret=\${SECRET}\"
"
```

Expected: HTTP 200 with `{"message":"Seems to have worked!"}`. Inspect the run:
```bash
ssh giorgiocaizzi@pi.local 'docker service logs --tail 400 -f firefly_importer'
```

Per-row `422 a115` ("duplicate hash") messages are **benign** — they mean the row was already imported. The default config has `IGNORE_DUPLICATE_ERRORS=false`, so the per-row error is logged but the batch continues.

## Updating the importer config (Swarm config rotation)

The importer reads `/var/www/html/import/config.json`, supplied as the Swarm config `firefly_importer_config`. Swarm configs are **immutable** — you cannot edit in place. Scaling the service to 0 is **not** enough because the service spec still references the config and holds a lock. The full rotation:

```bash
scp services/firefly/config/config.json giorgiocaizzi@pi.local:/tmp/importer_config.json
ssh giorgiocaizzi@pi.local '
  docker service update --config-rm firefly_importer_config firefly_importer &&
  docker config rm firefly_importer_config &&
  docker config create firefly_importer_config /tmp/importer_config.json &&
  rm /tmp/importer_config.json &&
  docker service update \
    --config-add source=firefly_importer_config,target=/var/www/html/import/config.json,mode=0444 \
    firefly_importer &&
  docker service scale firefly_importer=1
'
```

The four commands are: detach config from service → delete config → create new config from file → re-attach → ensure replica is up.

> `services/firefly/config/config.json` is **gitignored** because it contains the Firefly access token field (`"access_token": "eyJ..."`). Never commit it.

## Config shape (CSV import)

Minimal fields you almost always set:

```json
{
  "version": 3,
  "source": "csv",
  "created_at": "...",
  "date": "Ymd",
  "delimiter": "comma",
  "headers": true,
  "rules": true,
  "skip_form": false,
  "add_import_tag": true,
  "default_account": 1,
  "ignore_duplicate_transactions": true,
  "ignore_duplicate_lines": true,
  "specifics": [],
  "roles": [
    "date_transaction", "description", "amount", "opposing-name", "external-id"
  ],
  "do_mapping": [false, false, false, true, false],
  "mapping": {
    "3": {
      "AMZN MKTPLACE": 42,        // opposing column -> Firefly account id
      "TFL TRAVEL": 17
    }
  },
  "duplicate_detection_method": "classic",
  "unique_column_index": 4,
  "unique_column_type": "external-id",
  "flow": "csv"
}
```

Generate this from the UI rather than authoring by hand: upload a sample CSV, walk the wizard, then **Download configuration** at the end of the preview step. Drop the file into `services/firefly/config/config.json` and use the rotation command above to push it.

Place the actual data CSV next to the config under `/var/www/html/import/`. For multiple feeds, name each pair the same: `<feed>.json` + `<feed>.csv`. The importer auto-pairs by basename.

## Lunch Flow integration

[Lunch Flow](https://www.lunchflow.app/) is a SaaS that aggregates EU bank feeds and pushes them to the importer's "Lunch Flow" destination.

1. Sign up, connect banks.
2. In Lunch Flow → **Destinations → Add → API → Firefly III**.
3. Set the destination URL to `https://firefly-importer.giocaizzi.xyz`.
4. Copy the API key into the secret:
   ```bash
   echo -n "<api_key>" | ssh giorgiocaizzi@pi.local 'docker secret create firefly_lunch_flow_api_key -'
   docker service update --force firefly_importer
   ```
5. Lunch Flow now POSTs new transactions directly; you don't need the autoimport cron for it.

## Spectre / Nordigen (PSD2 bank feeds)

If you choose to drive imports from the importer's built-in PSD2 connectors instead of Lunch Flow:

- Spectre: set `SPECTRE_APP_ID` + `SPECTRE_SECRET` env in the compose service (don't bake into the image — use secrets).
- Nordigen / GoCardless: set `NORDIGEN_ID` + `NORDIGEN_KEY`.
- Then UI flow: → Spectre/Nordigen → pick institution → consent → preview → import. The generated config can be reused via auto-import the same way as CSV.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `401 Unauthenticated` on `/autoimport` | Wrong/expired Personal Access Token | Rotate `firefly_access_token` secret + `service update --force firefly_scheduler` |
| `403 Forbidden` on `/autoimport` | Bad `?secret=` query param | Check `firefly_auto_import_secret` matches `AUTO_IMPORT_SECRET` env |
| `422 a115` floods | Reimport of already-stored rows | Expected with `IGNORE_DUPLICATE_ERRORS=false`; safe to ignore |
| `503 Service Unavailable` from importer | Importer can't reach `firefly-app` | Check `firefly_network` overlay is up; `docker exec firefly-importer wget -qO- http://firefly-app:8080/api/v1/about` |
| Config update hangs | Swarm config lock still held | Re-run the 4-step rotation; verify with `docker config ls \| grep firefly_importer_config` |
| Importer logs `Could not parse JSON config` | Stale/malformed `config.json` | Regenerate from UI, redo rotation |
| Lunch Flow shows "delivery failed" | Cloudflare tunnel down or API key mismatch | Test `https://firefly-importer.giocaizzi.xyz/api/v1/import` reachable; verify `firefly_lunch_flow_api_key` |
| Imported transactions don't get tagged | `add_import_tag: false` in config, or rules disabled (`"rules": false`) | Flip both true, re-run import (will dedupe via `external_id`) |
