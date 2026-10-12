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
# Needs DOMAIN, ALLOWED_EMAILS and KV_ID_<ENV> exported (see below); gh only to
# store the id of a newly created KV namespace.
#
# Idempotent: re-runnable. KV namespaces are created once; secrets you skip
# (press Enter) are left unchanged.
set -euo pipefail
cd "$(dirname "$0")"

CLOUD_DIR="../../cloud"
ENVS=(greenhouse firefly n8n grafana netdata portainer langfuse)

# terraform output name of each service's CF Access service-token id/secret
declare -A CF_ID=(
  [greenhouse]=claude_greenhouse_mcp_client_id
  [firefly]=claude_firefly_mcp_client_id
  [n8n]=claude_n8n_mcp_client_id
  [grafana]=claude_grafana_mcp_client_id
  [netdata]=claude_netdata_mcp_client_id
  [portainer]=claude_portainer_mcp_client_id
  [langfuse]=claude_langfuse_mcp_client_id
)
declare -A CF_SECRET=(
  [greenhouse]=claude_greenhouse_mcp_client_secret
  [firefly]=claude_firefly_mcp_client_secret
  [n8n]=claude_n8n_mcp_client_secret
  [grafana]=claude_grafana_mcp_client_secret
  [netdata]=claude_netdata_mcp_client_secret
  [portainer]=claude_portainer_mcp_client_secret
  [langfuse]=claude_langfuse_mcp_client_secret
)

wr() { npx wrangler -c wrangler.deploy.jsonc "$@"; }
tf_out() { terraform -chdir="$CLOUD_DIR" output -raw "$1"; }
put_secret() { printf '%s' "$2" | wr secret put "$1" --env "$3" >/dev/null; echo "    set $1"; }

npx wrangler whoami >/dev/null 2>&1 || { echo "Not logged in — run: npx wrangler login"; exit 1; }

read -rp "Google OAuth Client ID (Enter to skip): " GOOGLE_ID
GOOGLE_SECRET=""
if [ -n "$GOOGLE_ID" ]; then
  read -rsp "Google OAuth Client secret: " GOOGLE_SECRET; echo
fi

# Placeholders in wrangler.jsonc are rendered from the environment. CI reads them
# from secrets on the cloudflare-workers environment; locally export them first:
#   DOMAIN, ALLOWED_EMAILS and KV_ID_<ENV> (ids: `npx wrangler kv namespace list`).
# A missing KV_ID_<ENV> creates the namespace and stores its id as that secret.
# Values are never printed.
: "${DOMAIN:?export DOMAIN (the public zone)}"
: "${ALLOWED_EMAILS:?export ALLOWED_EMAILS (comma-separated login allowlist)}"
export DOMAIN ALLOWED_EMAILS
for env in "${ENVS[@]}"; do
  var="KV_ID_$(echo "$env" | tr '[:lower:]' '[:upper:]')"
  if [ -z "${!var:-}" ]; then
    echo "=== $env: creating KV namespace (export $var if it already exists)..."
    id=$(npx wrangler kv namespace create OAUTH_KV --env "$env" 2>&1 | grep -oiE '[a-f0-9]{32}' | head -1)
    [ -n "$id" ] || { echo "  KV create failed"; exit 1; }
    printf '%s' "$id" | gh secret set "$var" --env cloudflare-workers >/dev/null
    printf -v "$var" '%s' "$id"
    echo "  stored as secret $var on the cloudflare-workers environment"
  fi
  export "${var?}"
done
./render-config.sh

for env in "${ENVS[@]}"; do
  echo "=== $env ==="
  echo "  deploying..."
  wr deploy --env "$env"

  echo "  setting secrets..."
  put_secret CF_ACCESS_CLIENT_ID     "$(tf_out "${CF_ID[$env]}")"     "$env"
  put_secret CF_ACCESS_CLIENT_SECRET "$(tf_out "${CF_SECRET[$env]}")" "$env"
  [ -n "$GOOGLE_ID" ]     && put_secret GOOGLE_CLIENT_ID     "$GOOGLE_ID"     "$env"
  [ -n "$GOOGLE_SECRET" ] && put_secret GOOGLE_CLIENT_SECRET "$GOOGLE_SECRET" "$env"
  read -rsp "  UPSTREAM_BEARER for $env (Enter to skip): " bearer; echo
  [ -n "$bearer" ] && put_secret UPSTREAM_BEARER "$bearer" "$env"
  if [ "$env" = portainer ]; then
    read -rsp '  UPSTREAM_EXTRA_HEADERS JSON {"X-Portainer-API-Key":"ptr_..."} (Enter to skip): ' extra; echo
    [ -n "$extra" ] && put_secret UPSTREAM_EXTRA_HEADERS "$extra" "$env"
  fi
done

echo
echo "=== Google OAuth client → Authorized redirect URIs (add all) ==="
for env in "${ENVS[@]}"; do echo "  https://mcp-connector-$env.<your-subdomain>.workers.dev/callback"; done
echo "=== Claude.ai → Settings → Connectors → Add custom connector (URL) ==="
for env in "${ENVS[@]}"; do echo "  https://mcp-connector-$env.<your-subdomain>.workers.dev/mcp"; done
echo
echo "Your <your-subdomain> is shown in the 'Deployed to' URL printed by wrangler above."
