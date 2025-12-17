#!/bin/bash
# Load Docker secrets into environment variables
# This script runs early in the container startup via /etc/entrypoint.d/

export APP_KEY=$(cat /run/secrets/app_key)
export DB_PASSWORD=$(cat /run/secrets/db_password)
export STATIC_CRON_TOKEN=$(cat /run/secrets/static_cron_token)
