#!/bin/bash
set -e

# Create roles and databases for each tenant if they don't exist
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'n8n') THEN
            CREATE ROLE n8n WITH LOGIN;
        END IF;
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'miniflux') THEN
            CREATE ROLE miniflux WITH LOGIN;
        END IF;
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'twenty') THEN
            CREATE ROLE twenty WITH LOGIN;
        END IF;
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'firefly') THEN
            CREATE ROLE firefly WITH LOGIN;
        END IF;
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'langfuse') THEN
            CREATE ROLE langfuse WITH LOGIN;
        END IF;
    END
    \$\$;

    SELECT 'CREATE DATABASE n8n OWNER n8n' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'n8n')\gexec
    SELECT 'CREATE DATABASE miniflux OWNER miniflux' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'miniflux')\gexec
    SELECT 'CREATE DATABASE twenty OWNER twenty' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'twenty')\gexec
    SELECT 'CREATE DATABASE firefly OWNER firefly' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'firefly')\gexec
    SELECT 'CREATE DATABASE langfuse OWNER langfuse' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'langfuse')\gexec

    REVOKE ALL ON DATABASE n8n FROM PUBLIC;
    GRANT ALL PRIVILEGES ON DATABASE n8n TO n8n;

    REVOKE ALL ON DATABASE miniflux FROM PUBLIC;
    GRANT ALL PRIVILEGES ON DATABASE miniflux TO miniflux;

    REVOKE ALL ON DATABASE twenty FROM PUBLIC;
    GRANT ALL PRIVILEGES ON DATABASE twenty TO twenty;

    REVOKE ALL ON DATABASE firefly FROM PUBLIC;
    GRANT ALL PRIVILEGES ON DATABASE firefly TO firefly;

    REVOKE ALL ON DATABASE langfuse FROM PUBLIC;
    GRANT ALL PRIVILEGES ON DATABASE langfuse TO langfuse;
EOSQL
