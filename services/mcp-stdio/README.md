# 🔌 MCP stdio — stdio-only MCP servers over HTTP

Hosts MCP servers that only speak stdio behind
[supergateway](https://github.com/supercorp-ai/supergateway), which serves each one over
Streamable HTTP at its own path. Public URL: `https://mcp-stdio.<domain>/<server>/mcp`,
reached by the [mcp-connector](../../workers/mcp-connector/README.md) Worker through
Cloudflare Access. Design: [MCP edge](../../docs/wip/mcp-edge.md) (Phase 3).

| Server | Path | Package | Users |
|--------|------|---------|-------|
| `fli` | `/fli/mcp` | [`flights[mcp]`](https://github.com/punitarani/fli) (Google Flights) | shared, no user data |

Adding a server (e.g. Garmin): [runbook](../../docs/mcp-stdio.md).

---

## 🚀 Quick Start

**1. Build & push the image** (Swarm ignores `build:`, so the image is prebuilt, as for
`code` and `openclaw`). Use a new date tag on every rebuild and set it in
`docker-compose.yml`:

```sh
docker buildx build --platform linux/arm64 \
  -t ghcr.io/giocaizzi/rp5-mcp-stdio:<yyyy.mm.dd> \
  --push services/mcp-stdio
```

The Pi must be able to pull it (public GHCR package, or `docker login ghcr.io` on the Pi).

**2. Create the secrets** (see [Secrets](#-secrets)), then sync them to the Pi:

```sh
PI_SSH_USER=pi ./scripts/create_secrets.sh mcp-stdio
```

**3. Deploy via Portainer** (Remote Stack → this repo → `services/mcp-stdio`), then give
the stack a GitOps webhook and store its id as `WEBHOOK_ID_MCP_STDIO` on the `pi-services`
environment so releases redeploy it ([GitOps](../../docs/gitops.md)).

**4. Check** from the nginx container:

```sh
ssh pi@pi.local 'docker exec $(docker ps -q -f name=infra_proxy) \
  wget -qO- http://mcp-stdio_gateway:8000/healthz'   # ok
```

---

## 📦 Architecture

| Service | Image | Port | Role |
|---------|-------|------|------|
| `gateway` | `ghcr.io/giocaizzi/rp5-mcp-stdio:<tag>` | 8000 | supergateway + the server CLIs |

```
Worker ──(CF Access service token)──► nginx (mcp-stdio.<domain>) ──► gateway:8000
                                                                       ├─ /fli/mcp ─► fli-mcp (one process per session)
                                                                       └─ /healthz
```

- **Config** is [`servers.jsonc`](servers.jsonc), baked into the image: one entry per
  server, `apiKeyFile` per server, shared defaults (Streamable HTTP, stateful, 15 min
  session timeout). A server can also take a `tools` allowlist or a `toolPrefix`
  ([supergateway config](https://github.com/supercorp-ai/supergateway#several-servers-from-a-config-file)).
- **One process per session** (stateful mode): sessions don't share state; an idle session
  is reaped after `sessionTimeout`. Memory: ~120 MB gateway + ~135 MB per open fli session.
- **Pinned**: base images by version, supergateway with its whole tree
  ([`gateway/package-lock.json`](gateway/package-lock.json)), each server's Python
  dependencies hash-locked in `servers/<name>.txt` (compiled from `servers/<name>.in`).
- **Non-root** (`node`, uid 1000), `no-new-privileges`, no volumes, only on `rp5_public`.
- `npm audit` flags GHSA-6qxp-vccf-f47h in the MCP SDK's OAuth **client**; supergateway
  uses it only to connect to remote servers, which this stack doesn't do.

Update a pin: edit `servers/<name>.in` (or `gateway/package.json`), re-lock, rebuild:

```sh
cd services/mcp-stdio
uv pip compile servers/fli.in --python-version 3.12 \
  --python-platform aarch64-unknown-linux-gnu --generate-hashes --no-header -o servers/fli.txt
(cd gateway && npm install --package-lock-only --ignore-scripts)
```

---

## 🔐 Secrets

One API key per server, sent by the Worker as `Authorization: Bearer <key>`
(`UPSTREAM_BEARER`). The gateway refuses to start if a key file is missing or empty.

| Secret | Create (Secrets Manager project `rp5-homeserver`) |
|--------|----------------------------------------------------|
| `mcp-stdio_fli_api_key` | `bws secret create mcp-stdio_fli_api_key "$(openssl rand -hex 32)" <project-id>` |

The same value goes into the Worker's `UPSTREAM_BEARER` for the `fli` connector:
read it back with `bws secret get <secret-id> | jq -r .value` piped straight into
`wrangler secret put` ([mcp-connector](../../workers/mcp-connector/README.md)).

---

## ✅ Verify

```sh
# Without the service token, Access stops the request (403)
curl -s -o /dev/null -w '%{http_code}\n' -X POST https://mcp-stdio.<domain>/fli/mcp
# Without the key, the gateway answers 401 (from the nginx container)
ssh pi@pi.local 'docker exec $(docker ps -q -f name=infra_proxy) \
  wget -S -qO- --post-data={} http://mcp-stdio_gateway:8000/fli/mcp 2>&1 | head -1'
ssh pi@pi.local 'docker service logs --tail 50 mcp-stdio_gateway'
```
