# Restore a database

**When:** a database (Firefly, CRM, n8n, Miniflux, greenhouse, Pocket ID) is lost or corrupted, or for the restore test below. How the dumps are taken: [backup.md](../backup.md#database-dumps).
**Preconditions:** SSH to the Pi (`ssh pi.local`). Restoring overwrites the live database: take a fresh dump first (Backrest → plan `docker-volumes` → Backup now).

Helper used below (run on the Pi):
```bash
task() { docker ps --format '{{.Names}}' -f "label=com.docker.swarm.service.name=$1" | head -n1; }
```

## Steps
1. **Get the dump from a snapshot.** Backrest UI → `docker-volumes` plan → snapshot → browse to `/backup/docker-volumes/infra_backrest_dumps/_data/` → Restore to `/dumps/restore`. On the Pi the files are then in `/var/lib/docker/volumes/infra_backrest_dumps/_data/restore/backup/docker-volumes/infra_backrest_dumps/_data/`; set `D` to that path. For the latest dump, skip this step and use `D=/var/lib/docker/volumes/infra_backrest_dumps/_data`.
2. **Stop the writers** (scale back up in step 4):
   - Firefly: `docker service scale firefly_app=0 firefly_importer=0 firefly_scheduler=0`
   - CRM: `docker service scale crm_server=0 crm_worker=0`
   - n8n: `docker service scale n8n_app=0`
   - Miniflux: `docker service scale miniflux_app=0`
   - greenhouse: `docker service scale greenhouse_app=0`
   - Pocket ID: `docker service scale pocket-id_app=0`
3. **Load the dump:**
   - Firefly (MariaDB):
     ```bash
     sudo cat "$D/firefly.sql" | docker exec -i "$(task firefly_db)" sh -c 'MYSQL_PWD="$(cat /run/secrets/db_password)" mariadb -uroot "$MYSQL_DATABASE"'
     ```
   - CRM / n8n / Miniflux (Postgres; `crm_db`+`crm.sql`, `n8n_db`+`n8n.sql`, or `miniflux_db`+`miniflux.sql`):
     ```bash
     db=crm_db; f=crm.sql
     docker exec "$(task $db)" sh -c 'psql -U "$POSTGRES_USER" -d postgres -c "DROP DATABASE \"$POSTGRES_DB\" WITH (FORCE)" -c "CREATE DATABASE \"$POSTGRES_DB\" OWNER \"$POSTGRES_USER\""'
     sudo cat "$D/$f" | docker exec -i "$(task $db)" sh -c 'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" "$POSTGRES_DB"'
     ```
   - greenhouse (SQLite, app stopped):
     ```bash
     v=/var/lib/docker/volumes/greenhouse_greenhouse_data/_data
     sudo rm -f "$v/irrigation.db-wal" "$v/irrigation.db-shm"
     sudo install -o 1000 -g 1000 -m 644 "$D/greenhouse.db" "$v/irrigation.db"
     ```
   - Pocket ID (SQLite + uploads, app stopped). The import needs the same encryption key as the dump. Before step 2, copy it from the running task into a file (never printed): `k=$(mktemp); docker exec "$(task pocket-id_app)" cat /run/secrets/encryption_key > "$k"`; with no running task, write into `$k` the Secrets Manager key named by `secrets.encryption_key.name` in `services/pocket-id/docker-compose.yml` (`pocket-id_encryption_key`, or `_v<N>` after a rotation) instead. Then import in a one-off container of the service's image (runs as root; the entrypoint fixes `/app/data` ownership on the next start):
     ```bash
     img=$(docker service inspect pocket-id_app --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}')
     sudo cat "$D/pocket-id.zip" | docker run --rm -i --entrypoint /app/pocket-id \
       -v pocket-id_app_data:/app/data -v "$k":/run/secrets/encryption_key:ro \
       -e ENCRYPTION_KEY_FILE=/run/secrets/encryption_key "$img" import --yes --path -
     shred -u "$k"
     ```
4. **Start the writers** again with the same `docker service scale` commands set to `=1`.

## Verify
The app's UI shows the expected data, and its service is healthy: `docker service ps <stack>_app --format '{{.CurrentState}}' | head -1` is `Running`.

**Restore test** (no impact on live data; run after any change to the dump setup). Loads the latest dumps into throwaway containers; non-zero counts mean they restore cleanly.
```bash
D=/var/lib/docker/volumes/infra_backrest_dumps/_data
# Postgres: crm (owner twenty), n8n (owner n8n), miniflux (owner miniflux)
docker run -d --name restore-test -e POSTGRES_PASSWORD=test postgres:16-alpine
until docker exec restore-test pg_isready -qU postgres; do sleep 1; done; sleep 2
for db in crm:twenty n8n:n8n miniflux:miniflux; do
  f=${db%%:*}; role=${db##*:}
  docker exec restore-test psql -qU postgres -c "create role $role" -c "create database $f owner $role"
  sudo cat "$D/$f.sql" | docker exec -i restore-test psql -q -v ON_ERROR_STOP=1 -U postgres -d "$f" >/dev/null
  docker exec restore-test psql -U postgres -d "$f" -tAc "select count(*) from information_schema.tables where table_schema not in ('pg_catalog','information_schema')"
done
docker rm -f restore-test
# MariaDB: firefly. Wait for "init process done": the first ping answers the temporary init server.
docker run -d --name restore-test-mariadb -e MARIADB_ROOT_PASSWORD=test -e MARIADB_DATABASE=firefly mariadb:12.3
until docker logs restore-test-mariadb 2>&1 | grep -q "init process done"; do sleep 2; done
until docker exec restore-test-mariadb mariadb-admin -uroot -ptest ping >/dev/null 2>&1; do sleep 2; done
sudo cat "$D/firefly.sql" | docker exec -i restore-test-mariadb mariadb -uroot -ptest firefly
docker exec restore-test-mariadb mariadb -uroot -ptest -N firefly -e "select count(*) from transactions"
docker rm -f restore-test-mariadb
# SQLite: greenhouse
sudo python3 -c "import sqlite3; print(sqlite3.connect('file:$D/greenhouse.db?mode=ro', uri=True).execute('pragma integrity_check').fetchone())"
```
Expected: three table counts and a transaction count above 0, and `('ok',)`.

## Rollback
Load the dump taken in the preconditions with the same steps.

**Last verified:** 2026-10-18 by Claude Code (restore test only: crm 115 tables, n8n 158 tables, firefly 6834 transactions, greenhouse `ok`; the live restore steps are unverified)
