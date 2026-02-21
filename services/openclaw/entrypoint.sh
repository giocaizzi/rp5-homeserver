#!/bin/sh
# OpenClaw gateway entrypoint.
# Runs as node (uid 1000) — never as root.
# Injects Swarm secrets as env vars before exec.
set -eu

export OPENCLAW_GATEWAY_TOKEN
OPENCLAW_GATEWAY_TOKEN=$(cat /run/secrets/gateway_token)

# Inject Anthropic API key if secret exists
if [ -f /run/secrets/anthropic_api_key ]; then
  export ANTHROPIC_API_KEY
  ANTHROPIC_API_KEY=$(cat /run/secrets/anthropic_api_key)
fi

# Inject Telegram bot token if secret exists
if [ -f /run/secrets/telegram_bot_token ]; then
  export TELEGRAM_BOT_TOKEN
  TELEGRAM_BOT_TOKEN=$(cat /run/secrets/telegram_bot_token)
fi

exec node /app/dist/index.js gateway \
  --bind lan \
  --port 18789 \
  --allow-unconfigured
