#!/usr/bin/with-contenv sh
# Load Docker secrets as s6 environment variables
# This ensures PHP-FPM inherits them

if [ -f /run/secrets/app_key ]; then
    printf "%s" "$(cat /run/secrets/app_key)" > /var/run/s6/basedir/env/APP_KEY
fi

if [ -f /run/secrets/db_password ]; then
    printf "%s" "$(cat /run/secrets/db_password)" > /var/run/s6/basedir/env/DB_PASSWORD
fi

if [ -f /run/secrets/static_cron_token ]; then
    printf "%s" "$(cat /run/secrets/static_cron_token)" > /var/run/s6/basedir/env/STATIC_CRON_TOKEN
fi
