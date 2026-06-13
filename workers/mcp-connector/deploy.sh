#!/usr/bin/env bash
#
# Deploy + configure the mcp-connector Workers (one per upstream MCP server).
#
# PREREQS you must do first (cannot be automated):
#   1. npx wrangler login                 # interactive browser OAuth
#   2. A Google OAuth "Web application" client (Client ID + secret).
#      Its redirect URIs are the <worker-url>/callback printed by this script —
#      run the script once to learn the URLs, register them in the Google
#      client, then re-run and supply the Google credentials.
#
# The CF Access service-token credentials are pulled automatically from
# `terraform output` (cloud/), so you never handle them. You are prompted only
# for the Google client creds (shared) and each service's UPSTREAM_BEARER.
#
# Idempotent: re-runnable. KV namespaces are created once; secrets you skip
# (press Enter) are left unchanged.
set -euo pipefail
cd "$(dirname "$0")"

CLOUD_DIR="../../cloud"
ENVS=(greenhouse firefly n8n)

# terraform output name of each service's CF Access service-token id/secret
declare -A CF_ID=(
  [greenhouse]=claude_greenhouse_mcp_client_id
  [firefly]=claude_firefly_mcp_client_id
  [n8n]=claude_n8n_mcp_client_id
)
declare -A CF_SECRET=(
  [greenhouse]=claude_greenhouse_mcp_client_secret
  [firefly]=claude_firefly_mcp_client_secret
  [n8n]=claude_n8n_mcp_client_secret
)

wr() { npx wrangler "$@"; }
tf_out() { terraform -chdir="$CLOUD_DIR" output -raw "$1"; }
put_secret() { printf '%s' "$2" | wr secret put "$1" --env "$3" >/dev/null; echo "    set $1"; }

wr whoami >/dev/null 2>&1 || { echo "Not logged in — run: npx wrangler login"; exit 1; }

read -rp "Google OAuth Client ID (Enter to skip): " GOOGLE_ID
GOOGLE_SECRET=""
if [ -n "$GOOGLE_ID" ]; then
  read -rsp "Google OAuth Client secret: " GOOGLE_SECRET; echo
fi

for env in "${ENVS[@]}"; do
  echo "=== $env ==="
  ph="REPLACE_WITH_$(echo "$env" | tr '[:lower:]' '[:upper:]')_KV_ID"
  if grep -q "$ph" wrangler.jsonc; then
    echo "  creating KV namespace..."
    id=$(wr kv namespace create OAUTH_KV --env "$env" 2>&1 | grep -oiE '[a-f0-9]{32}' | head -1)
    [ -n "$id" ] || { echo "  KV create failed"; exit 1; }
    sed -i '' "s/$ph/$id/" wrangler.jsonc
    echo "  KV id: $id"
  fi

  echo "  deploying..."
  wr deploy --env "$env"

  echo "  setting secrets..."
  put_secret CF_ACCESS_CLIENT_ID     "$(tf_out "${CF_ID[$env]}")"     "$env"
  put_secret CF_ACCESS_CLIENT_SECRET "$(tf_out "${CF_SECRET[$env]}")" "$env"
  [ -n "$GOOGLE_ID" ]     && put_secret GOOGLE_CLIENT_ID     "$GOOGLE_ID"     "$env"
  [ -n "$GOOGLE_SECRET" ] && put_secret GOOGLE_CLIENT_SECRET "$GOOGLE_SECRET" "$env"
  read -rsp "  UPSTREAM_BEARER for $env (Enter to skip): " bearer; echo
  [ -n "$bearer" ] && put_secret UPSTREAM_BEARER "$bearer" "$env"
done

echo
echo "=== Google OAuth client → Authorized redirect URIs (add all three) ==="
for env in "${ENVS[@]}"; do echo "  https://mcp-connector-$env.<your-subdomain>.workers.dev/callback"; done
echo "=== Claude.ai → Settings → Connectors → Add custom connector (URL) ==="
for env in "${ENVS[@]}"; do echo "  https://mcp-connector-$env.<your-subdomain>.workers.dev/mcp"; done
echo
echo "Your <your-subdomain> is shown in the 'Deployed to' URL printed by wrangler above."
