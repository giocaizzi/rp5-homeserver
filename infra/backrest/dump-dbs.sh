#!/bin/bash
# Logical database dumps, run by Backrest before each docker-volumes snapshot
# (CONDITION_SNAPSHOT_START hook, ON_ERROR_FATAL). See docs/backup.md.
# docker talks to infra_docker-proxy, which only allows exec into the tasks
# below; each dump runs with the DB container's own credentials.
# Dump commands are single-quoted on purpose: they expand inside the DB container.
# shellcheck disable=SC2016
set -uo pipefail

OUT=/dumps
fail=0

# dump <swarm service> <output file> <command run inside the container>
dump() {
  local name err
  name=$(docker ps --format '{{.Names}}' --filter "label=com.docker.swarm.service.name=$1" | head -n1)
  if [ -z "$name" ]; then
    # A stopped stack has no service: skip it and keep its last dump (older ones
    # stay in the snapshots). A deployed service with no running task is an error.
    err=$(docker service inspect "$1" 2>&1 >/dev/null)
    if [[ "$err" == *"no such service"* ]]; then
      echo "WARN: $1 not deployed (stack stopped), skipped; keeping the last $2" >&2
      return 0
    fi
    echo "ERROR: $1 has no running task ${err:+($err)}" >&2
    return 1
  fi
  if docker exec "$name" sh -c "$3" > "$OUT/$2.tmp" && [ -s "$OUT/$2.tmp" ]; then
    mv "$OUT/$2.tmp" "$OUT/$2"
    echo "ok $2 $(stat -c %s "$OUT/$2") bytes"
  else
    rm -f "$OUT/$2.tmp"
    echo "ERROR: dump of $1 failed" >&2
    return 1
  fi
}

# Dump from shared postgres if the DB exists, otherwise fallback to dedicated stack DB
dump_pg() {
  local db="$1" file="$2" dedicated_svc="$3" pg_user="${4:-postgres}"
  local pg_name
  pg_name=$(docker ps --format '{{.Names}}' --filter "label=com.docker.swarm.service.name=infra_postgres" | head -n1)
  if [ -n "$pg_name" ] && [ "$(docker exec "$pg_name" psql -U postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$db'")" = "1" ]; then
    if docker exec "$pg_name" pg_dump -U "$pg_user" "$db" > "$OUT/$file.tmp" && [ -s "$OUT/$file.tmp" ]; then
      mv "$OUT/$file.tmp" "$OUT/$file"
      echo "ok $file (shared postgres) $(stat -c %s "$OUT/$file") bytes"
      return 0
    else
      rm -f "$OUT/$file.tmp"
      echo "ERROR: dump of $db from infra_postgres failed" >&2
      return 1
    fi
  fi
  dump "$dedicated_svc" "$file" 'pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB"'
}

dump_firefly() {
  local pg_name
  pg_name=$(docker ps --format '{{.Names}}' --filter "label=com.docker.swarm.service.name=infra_postgres" | head -n1)
  if [ -n "$pg_name" ] && [ "$(docker exec "$pg_name" psql -U postgres -tAc "SELECT 1 FROM pg_database WHERE datname='firefly'")" = "1" ]; then
    if docker exec "$pg_name" pg_dump -U postgres firefly > "$OUT/firefly.sql.tmp" && [ -s "$OUT/firefly.sql.tmp" ]; then
      mv "$OUT/firefly.sql.tmp" "$OUT/firefly.sql"
      echo "ok firefly.sql (shared postgres) $(stat -c %s "$OUT/firefly.sql") bytes"
      return 0
    else
      rm -f "$OUT/firefly.sql.tmp"
      echo "ERROR: dump of firefly from infra_postgres failed" >&2
      return 1
    fi
  fi
  dump firefly_db firefly.sql \
    'MYSQL_PWD="$(cat /run/secrets/db_password)" mariadb-dump -uroot --single-transaction --routines --triggers "$MYSQL_DATABASE"'
}

dump_firefly || fail=1
dump_pg twenty crm.sql crm_db || fail=1
dump_pg n8n n8n.sql n8n_db || fail=1
dump_pg miniflux miniflux.sql miniflux_db || fail=1
# SQLite online backup into memory, streamed out (no temp file in the container)
dump greenhouse_app greenhouse.db \
  "python3 -c 'import sqlite3, sys; s = sqlite3.connect(\"/app/data/irrigation.db\"); d = sqlite3.connect(\":memory:\"); s.backup(d); sys.stdout.buffer.write(d.serialize())'" || fail=1
# Pocket ID CLI export (SQLite DB + uploads as a zip on stdout). Upstream marks
# export experimental, so the raw volume stays in the backup as a second copy.
# su-exec runs it as the app user, so no root-owned files land in /app/data.
dump pocket-id_app pocket-id.zip 'su-exec "${PUID:-1000}:${PGID:-1000}" /app/pocket-id export --path -' || fail=1

exit "$fail"
