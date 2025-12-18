#!/command/with-contenv sh
# Load Docker secrets as environment variables for Firefly III
# Reads _FILE variables and exports the actual secret values

if [ -n "$APP_KEY_FILE" ] && [ -f "$APP_KEY_FILE" ]; then
    export APP_KEY="$(cat "$APP_KEY_FILE")"
fi

if [ -n "$DB_PASSWORD_FILE" ] && [ -f "$DB_PASSWORD_FILE" ]; then
    export DB_PASSWORD="$(cat "$DB_PASSWORD_FILE")"
fi

if [ -n "$STATIC_CRON_TOKEN_FILE" ] && [ -f "$STATIC_CRON_TOKEN_FILE" ]; then
    export STATIC_CRON_TOKEN="$(cat "$STATIC_CRON_TOKEN_FILE")"
fi
