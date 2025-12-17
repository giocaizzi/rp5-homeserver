#!/bin/sh
# Write Docker secrets to .env file for Laravel
# This script runs early in the container startup

# Create .env file with secrets
cat > /var/www/html/.env << EOF
APP_KEY=$(cat /run/secrets/app_key)
DB_PASSWORD=$(cat /run/secrets/db_password)
STATIC_CRON_TOKEN=$(cat /run/secrets/static_cron_token)
EOF

# Set proper ownership
chown www-data:www-data /var/www/html/.env
chmod 600 /var/www/html/.env
