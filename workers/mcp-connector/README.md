# 🔌 mcp-connector — Claude.ai MCP connectors for self-hosted servers

A single Cloudflare Worker codebase, deployed once per server in
[`registry.json`](registry.json), that makes a self-hosted MCP server connectable
from **Claude.ai (web + Desktop)** as a custom connector — with OAuth login gated
to Google identities in the groups allowed on that connector, and the origin never
exposed unauthenticated.

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
| Google Flights | `https://mcp-connector-fli.<account>.workers.dev/mcp`      | `https://mcp-stdio.<domain>/fli/mcp` ([stdio via supergateway](../../services/mcp-stdio/README.md)) |
| Garmin Connect | `https://mcp-connector-garmin.<account>.workers.dev/mcp`   | `https://mcp-stdio.<domain>/garmin/mcp` ([stdio via supergateway](../../services/mcp-stdio/README.md)) |

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
    W-->>C: consent page (client name, redirect host)
    C->>W: POST /authorize (Allow)
    W->>G: redirect to Google login
    G->>W: GET /callback (code)
    W->>W: verify email ∈ allowed groups
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
| `src/google-handler.ts` | `/authorize` → consent page → Google; `/callback` → email allowlist → complete auth. |
| `src/policy.ts`     | Group allowlist and redirect-URI allowlist (Claude, VS Code, loopback).     |
| `src/proxy.ts`      | Token-gated `/mcp` reverse proxy; injects upstream auth; streams response; audit log. |
| `src/env.ts`        | Typed bindings (vars + secrets + KV + OAuthProvider).                       |
| `registry.json`     | One entry per server: display name, upstream, auth scheme, mode, allowed groups. |
| `wrangler.jsonc`    | Shared Worker settings (no envs).                                           |
| `render-config.sh`  | Generates one `env.<id>` per registry server into `wrangler.deploy.jsonc`, filling private values from the environment; `--check` validates the registry. |
| `deploy.sh`         | Idempotent deploy + secret-setting helper (pulls CF Access creds from TF).  |

---

## 🔐 Security model

Three independent gates protect the Pi origin; all must pass:

1. **Identity (who):** OAuth login via Google, restricted to members of the
   groups the connector allows (`allow` in `registry.json`; membership in
   `MCP_GROUPS`, see [Configuration](#-configuration)). The check runs at login,
   on every token refresh and on every `/mcp` call, so removing an address and
   redeploying revokes it immediately.
   - **Consent per client:** every authorization shows a consent page (client
     name, where the token goes, a warning for loopback) before the Google login;
     the library's helpers bind it to the browser and forbid framing.
   - **Redirect allowlist:** DCR and `/authorize` accept only
     `https://claude.ai/api/mcp/auth_callback`, `https://claude.com/api/mcp/auth_callback`,
     `https://vscode.dev/redirect` and loopback (`localhost`, `127.0.0.1`, `[::1]`)
     callbacks (`src/policy.ts`). Without it, a phishing link to `/authorize` with
     an attacker-registered client could mint a token for the attacker. Add a
     client's callback there before connecting it.
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

`registry.json` describes every server, keyed by id (the Worker is
`mcp-connector-<id>`, so an id never changes once a connector is in use):

| Field | Meaning |
|---|---|
| `name` | Display/log label (`SERVICE_NAME`). |
| `upstream` | The **full** upstream MCP endpoint, path included, with `${DOMAIN}` for the zone. |
| `auth` | Scheme for `UPSTREAM_BEARER`: `Bearer` or `Basic` (Langfuse). |
| `mode` | Identity propagation ([design](../../docs/wip/mcp-edge.md)); only `shared` is implemented. |
| `allow` | Groups whose members may use this connector. |
| `extra_headers` | Optional `true`: `deploy.sh` also prompts for `UPSTREAM_EXTRA_HEADERS`. |

Group **membership** is private and never in the repo. It comes from the
`MCP_GROUPS` secret, a JSON object `{"owner": ["<email>"], "friends": ["<email>"]}`;
while it is unset, every address in `ALLOWED_EMAILS` (comma-separated) is in group
`owner` and no other group exists.

`render-config.sh` turns each registry entry into an `env.<id>` with vars
`SERVICE_NAME`, `UPSTREAM_URL`, `UPSTREAM_AUTH_SCHEME`, `ALLOW_GROUPS`,
`ALLOWED_EMAILS` and `MCP_GROUPS`, and a dedicated **KV namespace** (`OAUTH_KV`,
id from `KV_ID_<ID>`) that stores OAuth grants/tokens. It writes the gitignored
`wrangler.deploy.jsonc` and fails on an invalid registry or a missing value; every
deploy uses `-c wrangler.deploy.jsonc`. CI reads the values from **secrets** on
the `cloudflare-workers` environment (`DOMAIN`, `ALLOWED_EMAILS`, `MCP_GROUPS`,
`KV_ID_<ID>`), so they are masked in the logs, including step env headers. Never
pass private values as GitHub variables: variable values are printed in clear.

`deploy.sh` creates a missing KV namespace and stores its id as that secret.

---

## 🚢 Deployment

**Routine deploys are automatic:** publishing an `mcp-connector` release
(`mcp-connector-v*`, via the release-please PR) runs `deploy-workers.yml`, which
typechecks, renders the config (values masked in the logs) and runs
`wrangler deploy --env` for every server in `registry.json` (secrets persist). It needs the
`cloudflare-workers` GitHub environment with `CLOUDFLARE_API_TOKEN` (Workers
Scripts:Edit), `CLOUDFLARE_ACCOUNT_ID` and the secrets above. Use the manual flow below for
bootstrap (KV, secrets) or a one-off deploy.

```bash
cd workers/mcp-connector
npm install
npx wrangler login

# export DOMAIN, ALLOWED_EMAILS, KV_ID_<ID> (ids: `npx wrangler kv namespace list`)
# and optionally MCP_GROUPS first

# guided: creates KV (if needed), deploys each env, sets secrets
./deploy.sh

# or per server: render, then deploy the rendered config
./render-config.sh <id>
npx wrangler deploy -c wrangler.deploy.jsonc --env <id>
npm run typecheck
```

**Logs / audit:** `npx wrangler tail mcp-connector-<id> --format pretty`, or the
Worker's logs in the Cloudflare dashboard (private). Every `/mcp` call writes one
JSON line `{"audit":"mcp","server","user","method","tool","status"}` (`method` and
`tool` from the `Mcp-Method`/`Mcp-Name` headers, null for older clients), as a
`warn` with the upstream `ct` (content-type) when the status is 4xx/5xx — enough
to distinguish an origin WAF block (`403 text/plain`), a bad bearer (`401`), an
app error, and a denied user (`403` without `ct`). Bodies and tokens are never
logged.

### ➕ Adding a server

Runbook; the Worker id is permanent once the connector is added in Claude.ai.

1. Expose the upstream behind Cloudflare Access with a `claude_<id>_mcp` service
   token and bypass policy in `cloud/` (Terraform outputs
   `claude_<id>_mcp_client_id` / `_secret`), as for the existing services.
2. Add one entry to `registry.json` and check it: `make lint` (runs
   `render-config.sh --check`).
3. Bootstrap from a machine with `wrangler login`, `terraform` access to `cloud/`
   and `gh`: export the variables above and run `./deploy.sh`. It creates the
   missing KV namespace (stored as secret `KV_ID_<ID>` on `cloudflare-workers`),
   deploys and prompts for the secrets (Enter skips the ones already set).
4. Add `https://mcp-connector-<id>.<account>.workers.dev/callback` to the Google
   OAuth client's redirect URIs.
5. Merge; the next `mcp-connector` release deploys it with the others. Add the
   connector URL in Claude.ai and the table at the top of this README.

To let a group in, add it to the server's `allow`; to change who is in a group,
update the `MCP_GROUPS` secret and redeploy (`workflow_dispatch` on
`deploy-workers.yml`).

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
