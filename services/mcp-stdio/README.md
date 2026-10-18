# 🔌 MCP stdio — stdio-only MCP servers over HTTP

Hosts MCP servers that only speak stdio behind
[supergateway](https://github.com/supercorp-ai/supergateway), which serves each one over
Streamable HTTP at its own path. Public URL: `https://mcp-stdio.<domain>/<server>/mcp`,
reached by the [mcp-connector](../../workers/mcp-connector/README.md) Worker through
Cloudflare Access. Design: [MCP edge](../../docs/wip/mcp-edge.md) (Phase 3).

| Server | Path | Package | Users |
|--------|------|---------|-------|
| `fli` | `/fli/mcp` | [`flights[mcp]`](https://github.com/punitarani/fli) (Google Flights) | shared, no user data |
| `garmin` | `/garmin/mcp` | [Taxuspt/garmin_mcp](https://github.com/Taxuspt/garmin_mcp) (Garmin Connect, all tools) | owner only |
| `surfline` | `/surfline/mcp` | [giocaizzi/pysurfline](https://github.com/giocaizzi/pysurfline) `[mcp]` (Surfline forecasts, private repo) | owner only |
| `lamma` | `/lamma/mcp` | [giocaizzi/pylamma](https://github.com/giocaizzi/pylamma) `[mcp]` (LaMMA Toscana wind and sea forecasts, private repo) | owner only |

Adding a server: [runbook](../../docs/mcp-stdio.md). Garmin needs a one-time interactive
login after the first deploy: [Garmin](../../docs/mcp-stdio.md#garmin).

---

## 🚀 Quick Start

**1. Build & push the image** (Swarm ignores `build:`, so the image is prebuilt, as for
`code` and `openclaw`). Use a new date tag on every rebuild and set it in
`docker-compose.yml`:

pysurfline and pylamma are private, so their wheels are built locally from a pinned commit
and passed as the `pysurfline` and `pylamma` build contexts (every rebuild needs both):

```sh
git -C ~/Documents/github/pysurfline fetch && git -C ~/Documents/github/pysurfline worktree add /tmp/pysurfline-build <commit>
uv build --wheel --directory /tmp/pysurfline-build --out-dir /tmp/pysurfline-dist
git -C ~/Documents/github/pylamma fetch && git -C ~/Documents/github/pylamma worktree add /tmp/pylamma-build <commit>
uv build --wheel --directory /tmp/pylamma-build --out-dir /tmp/pylamma-dist
docker buildx build --platform linux/arm64 \
  --build-context pysurfline=/tmp/pysurfline-dist \
  --build-context pylamma=/tmp/pylamma-dist \
  --label com.giocaizzi.pysurfline.commit=<commit> \
  --label com.giocaizzi.pylamma.commit=<commit> \
  -t ghcr.io/giocaizzi/rp5-mcp-stdio:<yyyy.mm.dd> \
  --push services/mcp-stdio
git -C ~/Documents/github/pysurfline worktree remove /tmp/pysurfline-build
git -C ~/Documents/github/pylamma worktree remove /tmp/pylamma-build
```

Each `-dist` directory must hold exactly one wheel; the labels record which commits they are. The GHCR
package is public, so the image ships pysurfline's and pylamma's code (accepted).

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
                                                                       ├─ /garmin/mcp ─► garmin-mcp (one process per session)
                                                                       ├─ /surfline/mcp ─► surfline-mcp (one process per session)
                                                                       ├─ /lamma/mcp ─► lamma-mcp (one process per session)
                                                                       └─ /healthz
```

- **Config** is [`servers.jsonc`](servers.jsonc), baked into the image: one entry per
  server, `apiKeyFile` per server, shared defaults (Streamable HTTP, stateful, 15 min
  session timeout). A server can also take a `tools` allowlist or a `toolPrefix`
  ([supergateway config](https://github.com/supercorp-ai/supergateway#several-servers-from-a-config-file)).
- **One process per session** (stateful mode): sessions don't share state; an idle session
  is reaped after `sessionTimeout`. Memory: ~120 MB gateway + ~135 MB per open session.
- **Pinned**: base images by version, supergateway with its whole tree
  ([`gateway/package-lock.json`](gateway/package-lock.json)), each server's Python
  dependencies hash-locked in `servers/<name>.txt` (compiled from `servers/<name>.in`).
  Garmin is not on PyPI: `servers/garmin.in` lists its dependencies and the package comes
  from a commit tarball pinned by `ADD --checksum` in the [`Dockerfile`](Dockerfile).
  pysurfline is private: `servers/surfline.in` pins `pysurfline[mcp]`'s dependencies (from
  its `uv.lock`) and the wheel comes from the `pysurfline` build context; pylamma likewise
  (`servers/lamma.in`, `pylamma` build context).
- **Non-root** (`node`, uid 1000), `no-new-privileges`, only on `rp5_public`. One volume,
  `garmin_data` (Garmin OAuth tokens, no password), backed up by Backrest.
- `npm audit` flags GHSA-6qxp-vccf-f47h in the MCP SDK's OAuth **client**; supergateway
  uses it only to connect to remote servers, which this stack doesn't do.

Update a pin: edit `servers/<name>.in` (or `gateway/package.json`), re-lock, rebuild:

```sh
cd services/mcp-stdio
uv pip compile servers/fli.in --python-version 3.12 \
  --python-platform aarch64-unknown-linux-gnu --generate-hashes --no-header -o servers/fli.txt
(cd gateway && npm install --package-lock-only --ignore-scripts)
```

Bump Garmin: copy the dependencies of the new commit's `pyproject.toml` into
`servers/garmin.in`, re-lock it as above, and update the tarball URL and its
`sha256` (`curl -sL <url> | shasum -a 256`) in the `Dockerfile`.

Bump pysurfline: copy the `curl-cffi`, `httpx`, `pydantic`, `fastmcp`, `matplotlib`,
`numpy` and `pillow` pins of the new commit (`uv export --extra mcp --no-dev
--no-emit-project` in pysurfline; `[mcp]` pulls in the `charts` and `plot` extras) into
`servers/surfline.in`, re-lock it as above, and build from that commit.

Bump pylamma: same, with the `fastmcp`, `httpx`, `numpy`, `pillow`, `pydantic` and
`xarray` pins (`uv export --extra mcp --no-dev --no-emit-project` in pylamma) into
`servers/lamma.in`.

---

## 🔐 Secrets

One API key per server, sent by the Worker as `Authorization: Bearer <key>`
(`UPSTREAM_BEARER`). The gateway refuses to start if a key file is missing or empty.

| Secret | Create (Secrets Manager project `rp5-homeserver`) |
|--------|----------------------------------------------------|
| `mcp-stdio_fli_api_key` | `bws secret create mcp-stdio_fli_api_key "$(openssl rand -hex 32)" <project-id>` |
| `mcp-stdio_garmin_api_key` | `bws secret create mcp-stdio_garmin_api_key "$(openssl rand -hex 32)" <project-id>` |
| `mcp-stdio_surfline_api_key` | `bws secret create mcp-stdio_surfline_api_key "$(openssl rand -hex 32)" <project-id>` |
| `mcp-stdio_lamma_api_key` | `bws secret create mcp-stdio_lamma_api_key "$(openssl rand -hex 32)" <project-id>` |

Each value also goes into the Worker's `UPSTREAM_BEARER` for the matching connector:
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
