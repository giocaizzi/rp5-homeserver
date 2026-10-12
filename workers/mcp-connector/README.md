# 🔌 mcp-connector — Claude.ai MCP connectors for self-hosted servers

A single Cloudflare Worker codebase, deployed once per upstream, that makes a
self-hosted MCP server connectable from **Claude.ai (web + Desktop)** as a custom
connector — with OAuth login gated to the owner's Google identity and the origin
never exposed unauthenticated.

Live connectors:

| Service    | Connector URL (add this in Claude.ai)                          | Upstream MCP endpoint (on the Pi)                  |
|------------|----------------------------------------------------------------|---------------------------------------------------|
| Greenhouse | `https://mcp-connector-greenhouse.<account>.workers.dev/mcp`   | `https://greenhouse.<domain>/mcp`            |
| Firefly III| `https://mcp-connector-firefly.<account>.workers.dev/mcp`      | `https://firefly.<domain>/api/v1/mcp`        |
| n8n        | `https://mcp-connector-n8n.<account>.workers.dev/mcp`          | `https://n8n.<domain>/mcp-server/http`       |
| Grafana    | `https://mcp-connector-grafana.<account>.workers.dev/mcp`      | `https://grafana.<domain>/mcp` (sidecar, read-only) |
| Netdata    | `https://mcp-connector-netdata.<account>.workers.dev/mcp`  | `https://netdata-mcp.<domain>/mcp` (native)  |
| Portainer  | `https://mcp-connector-portainer.<account>.workers.dev/mcp`    | `https://portainer.<domain>/mcp` (sidecar, full access) |
| Langfuse   | `https://mcp-connector-langfuse.<account>.workers.dev/mcp`     | `https://langfuse-mcp.<domain>/api/public/mcp` (native) |

---

## 🚀 Quick Start

Add a connector in Claude.ai → **Settings → Connectors → Add custom connector**,
paste the connector URL above, and complete the Google login. That's it — Claude.ai
self-registers (DCR), runs OAuth, and starts an MCP session.

To deploy/operate the Workers yourself, see [Deployment](#-deployment).

---

## 📦 Architecture

The Worker is **both** the OAuth 2.1 authorization server **and** the MCP resource,
on **one origin**. That single-origin property is the whole point (see
[Why a Worker](#-why-a-worker-design-rationale)). Login is delegated to Google;
the `/mcp` route is a token-gated reverse proxy to the Pi.

```mermaid
sequenceDiagram
    participant C as Claude.ai
    participant W as Worker (workers.dev)
    participant G as Google
    participant P as Upstream MCP (Pi, via CF Tunnel)

    C->>W: POST /mcp (no token)
    W-->>C: 401 + WWW-Authenticate (resource_metadata)
    C->>W: GET /.well-known/* , POST /register (DCR)
    C->>W: GET /authorize (PKCE S256)
    W->>G: redirect to Google login
    G->>W: GET /callback (code)
    W->>W: verify email ∈ ALLOWED_EMAILS
    W-->>C: redirect with auth code
    C->>W: POST /token  → access token
    C->>W: POST /mcp (Bearer worker-token)
    W->>P: proxy + inject CF-Access headers + UPSTREAM_BEARER
    P-->>W: MCP response (JSON / SSE)
    W-->>C: streamed back
```

**Files**

| File                | Role                                                                       |
|---------------------|----------------------------------------------------------------------------|
| `src/index.ts`      | Wires `OAuthProvider` (apiRoute `/mcp`, Google default handler).            |
| `src/google-handler.ts` | `/authorize` → Google; `/callback` → email allowlist → complete auth.   |
| `src/proxy.ts`      | Token-gated `/mcp` reverse proxy; injects upstream auth; streams response.  |
| `src/env.ts`        | Typed bindings (vars + secrets + KV + OAuthProvider).                       |
| `wrangler.jsonc`    | One `env.<service>` per upstream (name, vars, KV id placeholder).           |
| `render-config.sh`  | Fills the `${DOMAIN}` / `${KV_ID_<ENV>}` placeholders into `wrangler.deploy.jsonc`. |
| `deploy.sh`         | Idempotent deploy + secret-setting helper (pulls CF Access creds from TF).  |

---

## 🔐 Security model

Three independent gates protect the Pi origin; all must pass:

1. **Identity (who):** OAuth login via Google, restricted to `ALLOWED_EMAILS`.
   Only the owner can obtain a Worker access token.
2. **Cloudflare Access (edge):** the upstream hostname sits behind a path-scoped
   Access app. The Worker carries `CF-Access-Client-Id/Secret` for a `bypass`
   policy; no one else traverses Access to the origin.
3. **App bearer (origin):** the MCP server itself validates `Authorization:
   Bearer <UPSTREAM_BEARER>` (Firefly Passport PAT / n8n MCP token / greenhouse
   token). Fail-closed.

Secrets never touch Claude.ai or the browser — the Worker swaps Claude's OAuth
token for the upstream credentials server-side. The CF Access service-token
credentials and the `<svc>_mcp_policy` bypass apps are defined in `cloud/` (Terraform).

---

## 🔑 Secrets

Per-service, set with `wrangler secret put <NAME> --env <service>` (write-only;
never in `wrangler.jsonc`, never in argv with the value inline):

| Secret                  | Value                                                                  |
|-------------------------|------------------------------------------------------------------------|
| `GOOGLE_CLIENT_ID`      | Google OAuth "Web application" client id (shared across all envs).    |
| `GOOGLE_CLIENT_SECRET`  | …its secret (shared).                                                  |
| `UPSTREAM_BEARER`       | App-level bearer the upstream validates (per service — see below).      |
| `CF_ACCESS_CLIENT_ID`   | `terraform -chdir=cloud output -raw claude_<svc>_mcp_client_id`.        |
| `CF_ACCESS_CLIENT_SECRET` | `terraform -chdir=cloud output -raw claude_<svc>_mcp_client_secret`. |

`UPSTREAM_BEARER` per service:
- **firefly** — a Firefly III Personal Access Token (Profile → OAuth → Personal Access Tokens).
- **n8n** — the bearer of the n8n MCP Server Trigger node.
- **greenhouse** — the greenhouse `MCP_TOKEN`.
- **grafana** — the sidecar's caller token (`observability_grafana_mcp_server_token`, `MCP_GRAFANA_SERVER_TOKEN`), **not** the Grafana service-account token (that one stays inside the sidecar); the sidecar is also started `--disable-write`.
- **netdata** — the agent's MCP key: `docker exec $(docker ps -qf name=infra_monitoring) cat /var/lib/netdata/mcp_dev_preview_api_key`.
- **portainer** — the `infra_portainer_mcp_auth_token` gate token (the sidecar's `PORTAINER_MCP_AUTH_TOKEN`). Also set `UPSTREAM_EXTRA_HEADERS` (secret, JSON) to `{"X-Portainer-API-Key":"ptr_…"}` — a dedicated Portainer access token (My Account → Access tokens); it carries the full Portainer permissions of that user.
- **langfuse** — `base64(public_key:secret_key)` of the project key pair (`langfuse_public_key` / `langfuse_secret_key`), sent as `Authorization: Basic …` (`UPSTREAM_AUTH_SCHEME=Basic` in `wrangler.jsonc`). Langfuse MCP exposes write tools too.

**Google OAuth client** — one "Web application" client, with every callback
URL registered as Authorized redirect URIs (one per env, `https://mcp-connector-<env>.<account>.workers.dev/callback`):
```
https://mcp-connector-greenhouse.<account>.workers.dev/callback
https://mcp-connector-firefly.<account>.workers.dev/callback
https://mcp-connector-n8n.<account>.workers.dev/callback
https://mcp-connector-grafana.<account>.workers.dev/callback
https://mcp-connector-netdata.<account>.workers.dev/callback
https://mcp-connector-portainer.<account>.workers.dev/callback
https://mcp-connector-langfuse.<account>.workers.dev/callback
```

---

## ⚙️ Configuration

Non-secret, per-service `vars` live in `wrangler.jsonc`:

- `SERVICE_NAME` — display/log label.
- `UPSTREAM_URL` — the **full** upstream MCP endpoint (path included).
- `ALLOWED_EMAILS` — comma-separated login allowlist.
- `UPSTREAM_AUTH_SCHEME` — optional; scheme for `UPSTREAM_BEARER` (default `Bearer`, Langfuse `Basic`).

Each env also binds a dedicated **KV namespace** (`OAUTH_KV`) that stores OAuth
grants/tokens.

`wrangler.jsonc` holds placeholders, never real values: `${DOMAIN}` in the
`UPSTREAM_URL`s, `${ALLOWED_EMAILS}` and `${KV_ID_<ENV>}` for each KV id.
`render-config.sh` fills them from the environment into the gitignored
`wrangler.deploy.jsonc` and fails if one is missing; every deploy uses
`-c wrangler.deploy.jsonc`. CI reads them from **secrets** on the
`cloudflare-workers` environment (`DOMAIN`, `ALLOWED_EMAILS`, `KV_ID_<ENV>`), so
they are masked in the logs, including step env headers. Never pass private values
as GitHub variables: variable values are printed in clear.

`deploy.sh` creates a missing KV namespace and stores its id as that secret.

---

## 🚢 Deployment

**Routine deploys are automatic:** publishing an `mcp-connector` release
(`mcp-connector-v*`, via the release-please PR) runs `deploy-workers.yml`, which
typechecks, renders the config (values masked in the logs) and runs
`wrangler deploy --env` for every env (secrets persist). It needs the
`cloudflare-workers` GitHub environment with `CLOUDFLARE_API_TOKEN` (Workers
Scripts:Edit), `CLOUDFLARE_ACCOUNT_ID` and the placeholder secrets above. Use the manual flow below for
bootstrap (KV, secrets) or a one-off deploy.

```bash
cd workers/mcp-connector
npm install
npx wrangler login

# export DOMAIN, ALLOWED_EMAILS and KV_ID_<ENV> first (ids: `npx wrangler kv namespace list`)

# guided: creates KV (if needed), deploys each env, sets secrets
./deploy.sh

# or per service: render, then deploy the rendered config
./render-config.sh
npx wrangler deploy -c wrangler.deploy.jsonc --env <greenhouse|firefly|n8n|grafana|netdata|portainer|langfuse>
npm run typecheck
```

**Logs / debugging:** `npx wrangler tail --env <service> --format pretty`. The
proxy logs a one-line `warn` on any non-2xx upstream response (status +
content-type, never the body) — enough to distinguish an origin WAF block
(`403 text/plain`), a bad bearer (`401`), and an app error.

---

## 💡 Why a Worker (design rationale)

The earlier attempt used Cloudflare Access **"MCP Server Portals."** They deployed
and were OAuth-compliant, but Claude.ai web/Desktop **could not complete a session**
because the portal's authorization server lived on a *separate* host
(`*.cloudflareaccess.com`) from the MCP resource. Claude.ai's connector expects the
authorization server and the resource on the **same origin** (and trips Anthropic
bug #291 otherwise). The Worker collapses both onto one `workers.dev` origin, which
is exactly what Claude.ai handles — proven working for all three connectors.

### ⚠️ Gotcha: don't forward the browser's headers to the origin

Claude.ai's `/mcp` requests carry a large browser/SDK header set (`User-Agent`,
`sec-*`, `x-stainless-*`, tracing…). Forwarding that wholesale to a
Cloudflare-proxied origin trips a **WAF managed rule** → `403 "Your request was
blocked."`, which Claude.ai surfaces as *"Authorization with the MCP server failed."*
`proxy.ts` therefore forwards only an **allowlist** of MCP-required headers
(`content-type`, `accept`, `mcp-session-id`, `mcp-protocol-version`,
`last-event-id`) plus the injected auth and a stable `User-Agent`.

### Tool-name limit

Claude.ai rejects tool names longer than **64 characters**. An upstream whose MCP
tool names exceed that will connect but fail to load tools. (greenhouse hit this —
tracked in `giocaizzi/greenhouse#62`; the connector itself is fine.)
