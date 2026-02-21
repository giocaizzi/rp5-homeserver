#!/bin/sh
# OpenClaw gateway entrypoint.
# Runs as node (uid 1000) — never as root.
# Only purpose: inject the Swarm secret as an env var before exec.
set -eu

export OPENCLAW_GATEWAY_TOKEN
OPENCLAW_GATEWAY_TOKEN=$(cat /run/secrets/gateway_token)

exec node /app/dist/index.js gateway \
  --bind lan \
  --port 18789 \
  --allow-unconfigured
