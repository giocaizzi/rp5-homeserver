#!/bin/sh
# OpenClaw gateway entrypoint.
# Sets secrets as env vars, then execs the original Node.js image entrypoint
# which handles ownership (chown) and drops to uid 1000 before running the gateway.
set -eu

export OPENCLAW_GATEWAY_TOKEN
OPENCLAW_GATEWAY_TOKEN=$(cat /run/secrets/gateway_token)

export ANTHROPIC_API_KEY
ANTHROPIC_API_KEY=$(cat /run/secrets/anthropic_api_key)

if [ -f /run/secrets/telegram_bot_token ]; then
  export TELEGRAM_BOT_TOKEN
  TELEGRAM_BOT_TOKEN=$(cat /run/secrets/telegram_bot_token)
fi

if [ -f /run/secrets/notion_api_key ]; then
  export NOTION_API_KEY
  NOTION_API_KEY=$(cat /run/secrets/notion_api_key)
fi

if [ -f /run/secrets/brave_api_key ]; then
  export BRAVE_API_KEY
  BRAVE_API_KEY=$(cat /run/secrets/brave_api_key)
fi

exec /usr/local/bin/docker-entrypoint.sh \
  node /app/dist/index.js gateway \
  --bind lan \
  --port 18789 \
  --allow-unconfigured
