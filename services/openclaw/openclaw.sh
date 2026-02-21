#!/usr/bin/env bash
# Run an openclaw CLI command on the Pi gateway container.
# Usage: PI_SSH_USER=username ./scripts/openclaw.sh <command> [args...]
#
# Required environment variables:
#   PI_SSH_USER - SSH username for the Pi
#
# Optional environment variables:
#   PI_HOST - Pi hostname or IP (default: pi.local)
#
# Examples:
#   PI_SSH_USER=pi ./scripts/openclaw.sh doctor
#   PI_SSH_USER=pi ./scripts/openclaw.sh channels list
#   PI_SSH_USER=pi ./scripts/openclaw.sh channels add --channel telegram --token "<token>"
#   PI_SSH_USER=pi ./scripts/openclaw.sh onboard          # interactive (TTY allocated)

set -euo pipefail

PI_HOST="${PI_HOST:-pi.local}"
PI_SSH_USER="${PI_SSH_USER:?PI_SSH_USER is required}"

if [[ $# -eq 0 ]]; then
  echo "Usage: PI_SSH_USER=<user> $0 <command> [args...]" >&2
  exit 1
fi

# Serialize args safely for remote shell execution (trim trailing space)
REMOTE_ARGS=$(printf '%q ' "$@")
REMOTE_ARGS="${REMOTE_ARGS% }"

ssh -t "${PI_SSH_USER}@${PI_HOST}" \
  "docker exec -it \$(docker ps -q -f name=openclaw_gateway | head -1) \
   sh -c 'export OPENCLAW_GATEWAY_TOKEN=\$(cat /run/secrets/gateway_token); \
          export ANTHROPIC_API_KEY=\$(cat /run/secrets/anthropic_api_key 2>/dev/null); \
          export TELEGRAM_BOT_TOKEN=\$(cat /run/secrets/telegram_bot_token 2>/dev/null); \
          export OPENCLAW_GATEWAY_URL=ws://127.0.0.1:18789; \
          exec node /app/dist/index.js \"\$@\"' sh ${REMOTE_ARGS}"
