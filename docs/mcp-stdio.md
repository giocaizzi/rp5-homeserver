# Runbook: add a stdio MCP server

Stdio-only MCP servers run in [`services/mcp-stdio`](../services/mcp-stdio/README.md):
supergateway serves each at `https://mcp-stdio.<domain>/<id>/mcp`, one server process
per session, behind its own API key. claude.ai and remote CLIs reach it through the
[mcp-connector](../workers/mcp-connector/README.md) Worker. Design:
[MCP edge](./wip/mcp-edge.md) (Phase 3). `<id>` is lowercase `[a-z0-9-]+` and is the same
everywhere below (path, secret, Access token, registry key).

One PR per component, in this order (each lands on its own; nothing is live until the
last deploy step).

## 1. Stack (`services/mcp-stdio`, `feat(mcp-stdio):`)

1. Lock the server's Python dependencies (aarch64, Python 3.12):

   ```sh
   cd services/mcp-stdio
   printf '<package>==<version>\n' > servers/<id>.in
   uv pip compile servers/<id>.in --python-version 3.12 \
     --python-platform aarch64-unknown-linux-gnu --generate-hashes --no-header -o servers/<id>.txt
   ```

   A Node server instead goes into `gateway/package.json` (re-lock with
   `npm install --package-lock-only --ignore-scripts`) and runs from `/opt/gateway/node_modules/.bin`.
2. `Dockerfile`: add a venv next to fli's:
   `uv venv /opt/mcp/<id> --python 3.12 && uv pip install --python /opt/mcp/<id> --require-hashes -r /opt/mcp/requirements/<id>.txt`.
3. `servers.jsonc`: add `"<id>": { "command": "/opt/mcp/<id>/bin/<entrypoint>", "apiKeyFile": "/run/secrets/<id>_api_key" }`.
   Optional: `"tools": [...]` to expose only some tools, `"env": {...}`.
4. `docker-compose.yml`: secret `<id>_api_key` (external name `mcp-stdio_<id>_api_key`,
   `uid: "1000"`, `mode: 0400`); bump the image tag to today's date; raise the memory limit
   if the server is heavy (each open session is one process).
5. Check locally: `make check`, then build and run it (Docker Desktop on Apple silicon builds
   arm64 natively):

   ```sh
   docker buildx build --platform linux/arm64 --load -t rp5-mcp-stdio:test services/mcp-stdio
   docker run --rm -p 18000:8000 \
     -v "$PWD/fli.key:/run/secrets/fli_api_key:ro" \
     -v "$PWD/<id>.key:/run/secrets/<id>_api_key:ro" rp5-mcp-stdio:test
   ```

   Every server's key file must be mounted (any non-empty test value), or the gateway
   refuses to start. Expect `401` without
   `Authorization: Bearer <key>` on `/<id>/mcp`, and `initialize` + `tools/list` with it.

## 2. Access (`cloud/`, `feat(cloud):`)

Copy the `fli` block at the end of `cloud/main.tf`: service token `claude-<id>-mcp`, bypass
policy, path-scoped app on `mcp-stdio.${var.zone_name}/<id>/mcp`, and the two sensitive
outputs `claude_<id>_mcp_client_id` / `_secret` in `outputs.tf`. The host, DNS and nginx
route already exist. `cloud/` applies on merge: the plan comment must show only additions.

## 3. Connector (`workers/mcp-connector`, `feat(mcp-connector):`)

Registry entry: `"<id>": { "name": "...", "upstream": "https://mcp-stdio.${DOMAIN}/<id>/mcp", "auth": "Bearer", "mode": "shared", "allow": [...] }`,
then the [connector runbook](../workers/mcp-connector/README.md#-adding-a-server).

## 4. Secrets and deploy (operator)

```sh
# Gateway key (Secrets Manager project rp5-homeserver), then to the Pi
bws secret create mcp-stdio_<id>_api_key "$(openssl rand -hex 32)" <project-id>
PI_SSH_USER=pi ./scripts/create_secrets.sh mcp-stdio

# Image (date tag = the one in docker-compose.yml)
docker buildx build --platform linux/arm64 -t ghcr.io/giocaizzi/rp5-mcp-stdio:<tag> --push services/mcp-stdio
```

Then merge the `mcp-stdio` release (Portainer redeploys the stack), bootstrap the Worker
with `workers/mcp-connector/deploy.sh` (its `UPSTREAM_BEARER` prompt takes the same key:
`bws secret get <secret-id> | jq -r .value`), and add the connector URL in claude.ai.

Local CLIs: add the connector URL to `.chezmoidata/mcp.toml` in the dotfiles.

## Garmin (planned)

Garmin Connect is personal data and needs one interactive login, so it differs from fli:

- **Owner only.** `allow: ["owner"]` in the registry, never a shared group; its own Access
  app and service token as above.
- **Interactive first login.** The Garmin server keeps OAuth tokens on disk after a login
  that may ask for an MFA code. Add a named volume (e.g. `garmin_tokens`) mounted at the
  server's token directory, owned by uid 1000, and back it up with the other volumes. After
  the first deploy, log in once inside the running task:

  ```sh
  ssh -t pi@pi.local 'docker exec -it $(docker ps -q -f name=mcp-stdio_gateway) \
    /opt/mcp/garmin/bin/<login-command>'
  ```

  Then check `tools/list` through the gateway. Repeat when the tokens expire or Garmin
  invalidates them (calls start failing with an auth error in
  `docker service logs mcp-stdio_gateway`).
- **No credentials in env or secrets.** Email and password are typed at the login prompt
  only; the volume holds tokens, not the password.
