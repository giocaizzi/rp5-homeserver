#!/usr/bin/env bash
# Render wrangler.jsonc into wrangler.deploy.jsonc (gitignored), filling the
# ${DOMAIN} and ${KV_ID_<ENV>} placeholders from the environment. Fails if any
# placeholder has no value, so an unrendered config is never deployed.
# Deploy with: npx wrangler deploy -c wrangler.deploy.jsonc --env <env>
set -euo pipefail
cd "$(dirname "$0")"

# shellcheck disable=SC2016  # literal ${...} patterns
names=$(grep -oE '\$\{[A-Z0-9_]+\}' wrangler.jsonc | sort -u | tr -d '${}')
for n in $names; do
  [ -n "${!n:-}" ] || { echo "render-config: $n is not set" >&2; exit 1; }
done
# shellcheck disable=SC2016,SC2086  # envsubst takes a literal ${VAR} list; names split on purpose
envsubst "$(printf '${%s} ' $names)" < wrangler.jsonc > wrangler.deploy.jsonc
