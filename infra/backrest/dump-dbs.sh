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

dump firefly_db firefly.sql \
  'MYSQL_PWD="$(cat /run/secrets/db_password)" mariadb-dump -uroot --single-transaction --routines --triggers "$MYSQL_DATABASE"' || fail=1
dump crm_db crm.sql 'pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB"' || fail=1
dump n8n_db n8n.sql 'pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB"' || fail=1
# SQLite online backup into memory, streamed out (no temp file in the container)
dump greenhouse_app greenhouse.db \
  "python3 -c 'import sqlite3, sys; s = sqlite3.connect(\"/app/data/irrigation.db\"); d = sqlite3.connect(\":memory:\"); s.backup(d); sys.stdout.buffer.write(d.serialize())'" || fail=1

exit "$fail"
