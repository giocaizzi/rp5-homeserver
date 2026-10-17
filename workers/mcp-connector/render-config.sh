#!/usr/bin/env bash
# Render wrangler.jsonc + registry.json into wrangler.deploy.jsonc (gitignored):
# one `env.<id>` per registry server, with ${DOMAIN}, the group membership and
# KV_ID_<ID> filled from the environment. Fails on an invalid registry or a
# missing value, so an unrendered config is never deployed.
#
#   ./render-config.sh [id ...]   render the given servers (default: all)
#   ./render-config.sh --check    validate registry.json only (make lint)
#
# Environment: DOMAIN, ALLOWED_EMAILS, KV_ID_<ID> per rendered server, and
# optionally MCP_GROUPS, a JSON object {"<group>": ["<email>", ...]}; without it
# every ALLOWED_EMAILS address is in group `owner`.
# Deploy with: npx wrangler deploy -c wrangler.deploy.jsonc --env <id>
set -euo pipefail
cd "$(dirname "$0")"

# Implemented identity modes (docs/wip/mcp-edge.md); others fail until built.
jq -e '
  .servers | type == "object" and length > 0 and all(to_entries[];
    (.key | test("^[a-z0-9-]+$")) and
    (.value | (.name | type == "string") and
      (.upstream | type == "string" and startswith("https://")) and
      (.auth == "Bearer" or .auth == "Basic") and
      .mode == "shared" and
      (.allow | type == "array" and length > 0 and all(type == "string"))))
' registry.json >/dev/null || { echo "render-config: invalid registry.json" >&2; exit 1; }
[ "${1:-}" = --check ] && exit 0

# Ids are validated above as [a-z0-9-]+, so word splitting is safe.
# shellcheck disable=SC2207
if [ $# -gt 0 ]; then ids=("$@"); else ids=($(jq -r '.servers | keys_unsorted[]' registry.json)); fi
: "${DOMAIN:?render-config: DOMAIN is not set}"
: "${ALLOWED_EMAILS:?render-config: ALLOWED_EMAILS is not set}"
groups=${MCP_GROUPS:-}
if [ -n "$groups" ]; then
  jq -e 'type == "object" and all(.[]; type == "array" and all(type == "string"))' <<<"$groups" >/dev/null \
    || { echo "render-config: MCP_GROUPS is not a {group: [emails]} object" >&2; exit 1; }
  groups=$(jq -c . <<<"$groups")
fi
for id in "${ids[@]}"; do
  jq -e --arg id "$id" '.servers | has($id)' registry.json >/dev/null || { echo "render-config: no server $id in registry.json" >&2; exit 1; }
  var="KV_ID_$(tr '[:lower:]-' '[:upper:]_' <<<"$id")"
  [ -n "${!var:-}" ] || { echo "render-config: $var is not set" >&2; exit 1; }
  export "${var?}"
done

# wrangler.jsonc carries only full-line // comments; strip them for jq.
# shellcheck disable=SC2016  # ${DOMAIN} is a literal placeholder for jq
sed '/^[[:space:]]*\/\//d' wrangler.jsonc | jq \
  --slurpfile reg registry.json --arg ids "${ids[*]}" \
  --arg domain "$DOMAIN" --arg emails "$ALLOWED_EMAILS" --arg groups "$groups" '
  .env = ($reg[0].servers | with_entries(select(.key | IN($ids | split(" ")[])) | .key as $id | .value |= {
    name: "mcp-connector-\($id)",
    vars: {
      SERVICE_NAME: .name,
      UPSTREAM_URL: (.upstream | gsub("\\$\\{DOMAIN\\}"; $domain)),
      UPSTREAM_AUTH_SCHEME: .auth,
      ALLOW_GROUPS: (.allow | join(",")),
      ALLOWED_EMAILS: $emails,
      MCP_GROUPS: $groups
    },
    kv_namespaces: [{ binding: "OAUTH_KV", id: $ENV["KV_ID_\($id | ascii_upcase | gsub("-"; "_"))"] }]
  }))' > wrangler.deploy.jsonc
