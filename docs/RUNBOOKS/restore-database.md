# Restore a database

**When:** a database (Firefly, CRM, n8n, greenhouse) is lost or corrupted, or for the restore test below. How the dumps are taken: [backup.md](../backup.md#database-dumps).
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
   - greenhouse: `docker service scale greenhouse_app=0`
3. **Load the dump:**
   - Firefly (MariaDB):
     ```bash
     sudo cat "$D/firefly.sql" | docker exec -i "$(task firefly_db)" sh -c 'MYSQL_PWD="$(cat /run/secrets/db_password)" mariadb -uroot "$MYSQL_DATABASE"'
     ```
   - CRM / n8n (Postgres; `crm_db`+`crm.sql`, or `n8n_db`+`n8n.sql`):
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
4. **Start the writers** again with the same `docker service scale` commands set to `=1`.

## Verify
The app's UI shows the expected data, and its service is healthy: `docker service ps <stack>_app --format '{{.CurrentState}}' | head -1` is `Running`.

**Restore test** (no impact on live data; run after any change to the dump setup):
```bash
D=/var/lib/docker/volumes/infra_backrest_dumps/_data
docker run -d --name restore-test -e POSTGRES_PASSWORD=test postgres:16-alpine && sleep 5
sudo cat "$D/crm.sql" | docker exec -i restore-test psql -q -v ON_ERROR_STOP=1 -U postgres
docker exec restore-test psql -U postgres -tAc "select count(*) from information_schema.tables where table_schema not in ('pg_catalog','information_schema')"
docker rm -f restore-test
```
A non-zero table count means the dump restores cleanly. Role errors for the dump's owner are expected unless you create the role first; `ON_ERROR_STOP` stops on them, so run `docker exec restore-test psql -U postgres -c 'create role twenty'` before loading.

## Rollback
Load the dump taken in the preconditions with the same steps.

**Last verified:** not yet verified (restore test pending first deploy)
