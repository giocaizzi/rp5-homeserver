# Connecting Claude.ai Custom Connectors to Home MCP Servers

**Status:** Design / research (not yet implemented)
**Date:** 2026-06-01
**Scope:** Expose `greenhouse`, `firefly`, and `n8n` MCP servers to **Claude.ai**
(web + mobile) custom connectors.

---

## 1. Problem

Claude.ai custom connectors authenticate to a remote MCP server **only via
OAuth** (Dynamic Client Registration + PKCE S256, or a manually-entered OAuth
client id/secret). The "Add custom connector" UI has **no field for a bearer
token or arbitrary HTTP header**.

Anthropic closed the custom-header feature request
([anthropics/claude-ai-mcp#110](https://github.com/anthropics/claude-ai-mcp/issues/110))
as **"not planned"**, and the bearer-token request
([#112](https://github.com/anthropics/claude-ai-mcp/issues/112)) the same way.
The official recommendation is: **use OAuth**, or **deploy a proxy that adds
the headers**.

This is a hard constraint, not a bug to wait out.

> **Note — Claude Code/Desktop is different.** Those clients *can* set custom
> headers, which is why the existing MCP setup (see §2) works for them. This
> document is specifically about **Claude.ai**, which cannot.

---

## 2. Current state — what already exists

The repo already exposes all three MCP servers, but **for Claude Code/Desktop**,
using Cloudflare Access **service tokens** + an **app-level bearer**. Claude
Code sends both as headers; Claude.ai cannot.

| Service | Upstream MCP path | Outer gate (CF Access) | Inner gate (app auth) |
|---------|-------------------|------------------------|------------------------|
| greenhouse | `greenhouse.giocaizzi.xyz/mcp` | `greenhouse_users` email policy (whole host) | `Authorization: Bearer GREENHOUSE_MCP_TOKEN` (fail-closed ≥ v2.0.0) |
| firefly | `firefly.giocaizzi.xyz/api/v1/mcp` | path-scoped bypass app + `claude-firefly-mcp` service token | `Authorization: Bearer <Firefly PAT>` (`firefly_access_token`) |
| n8n | `n8n.giocaizzi.xyz/mcp-server` | path-scoped bypass app + `claude-n8n-mcp` service token | `Authorization: Bearer <n8n MCP token>` (set on the MCP Server Trigger node) |

Defined in `cloud/main.tf` (search "Claude Code MCP"). **None of this is
reachable from Claude.ai** — it all relies on the client sending headers.

The inner bearer secrets already exist as Docker Swarm secrets
(`greenhouse_mcp_token`, `firefly_access_token`, and the n8n token), so no new
secret material needs to be generated for the app layer.

---

## 3. Chosen approach — Cloudflare MCP Server Portal (Option A)

Cloudflare One **MCP Server Portals** (GA Aug 2025) front one or more MCP
servers behind a **portal URL**, run the **full OAuth flow with Claude via
Cloudflare Access**, and enforce existing Access policies (email, MFA, geo,
device posture).

### Decision — three separate connectors, not one aggregated

A portal maps 1:1 to a connector in Claude.ai. We use **three single-server
portals** (one per service) so greenhouse, firefly, and n8n each appear as
their **own connector** in Claude.ai — independently toggled, isolated, with
its own OAuth login. This preserves the per-token isolation already designed
into `cloud/main.tf` ("a leaked token for n8n cannot reach Firefly III's MCP").
The cost is three OAuth logins in Claude instead of one. (Aggregating all three
into a single portal/connector is the alternative — fewer logins, but a shared
surface and no per-service on/off; rejected.)

### 3.1 Key simplification — Cloudflare injects the inner bearer

The Terraform resource `cloudflare_zero_trust_access_ai_controls_mcp_server`
takes `auth_type = "oauth" | "bearer" | "unauthenticated"` and a sensitive
`auth_credentials`. With `auth_type = "bearer"`, **Cloudflare attaches the app
bearer to each upstream request itself**.

Consequences:

- **No nginx `proxy_set_header Authorization` injection is needed.** (This
  reverses the earlier plan that assumed nginx would inject the bearer.)
- Because nginx never rewrites the request, there is **no header-bleed risk**
  into the human web UIs on `firefly.*`/`n8n.*`. The portal can register the
  **existing** MCP paths directly.
- The **only new hostname required is the portal's own** (e.g.
  `mcp.giocaizzi.xyz`), not a `*-mcp` host per service.

### 3.2 Target architecture

Three independent connectors, each = one single-server portal:

```
Claude.ai ──OAuth──▶ greenhouse-mcp.…xyz  (portal) ─▶ greenhouse.…/mcp        bearer: GREENHOUSE_MCP_TOKEN
Claude.ai ──OAuth──▶ firefly-mcp.…xyz     (portal) ─▶ firefly.…/api/v1/mcp    bearer: Firefly PAT
Claude.ai ──OAuth──▶ n8n-mcp.…xyz         (portal) ─▶ n8n.…/mcp-server        bearer: n8n MCP token
```

Each connector does its own OAuth via CF Access; Cloudflare injects that
service's app bearer (`auth_type=bearer`). Claude sends **no** headers. The
existing Claude Code paths (service-token bypass) stay untouched and continue
to work in parallel.

---

## 4. Terraform sketch (in `cloud/main.tf`)

> Resource names verified against `cloudflare/cloudflare ~> 5.11`.
> The portal needs its **DNS record created separately** (the TF provider does
> not auto-create it, unlike the dashboard).

One DNS record + one single-server portal **per service** (three connectors).
Shown for greenhouse; firefly and n8n are identical with their own
host/path/token.

```hcl
# DNS record for each portal hostname → tunnel (one per connector).
resource "cloudflare_dns_record" "greenhouse_mcp_portal" {
  zone_id = var.zone_id
  name    = "greenhouse-mcp"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.homeserver.id}.cfargotunnel.com"
  type    = "CNAME"
  ttl     = 1
  proxied = true
}

# Register each upstream MCP server; CF injects the bearer via auth_credentials.
resource "cloudflare_zero_trust_access_ai_controls_mcp_server" "greenhouse" {
  account_id       = var.cloudflare_account_id
  id               = "greenhouse-mcp"
  name             = "Greenhouse"
  auth_type        = "bearer"
  hostname         = "https://greenhouse.${var.zone_name}/mcp"
  auth_credentials = var.greenhouse_mcp_token   # new sensitive tfvar
}

resource "cloudflare_zero_trust_access_ai_controls_mcp_server" "firefly" {
  account_id       = var.cloudflare_account_id
  id               = "firefly-mcp"
  name             = "Firefly III"
  auth_type        = "bearer"
  hostname         = "https://firefly.${var.zone_name}/api/v1/mcp"
  auth_credentials = var.firefly_mcp_token       # = Firefly PAT
}

resource "cloudflare_zero_trust_access_ai_controls_mcp_server" "n8n" {
  account_id       = var.cloudflare_account_id
  id               = "n8n-mcp"
  name             = "n8n"
  auth_type        = "bearer"
  hostname         = "https://n8n.${var.zone_name}/mcp-server"
  auth_credentials = var.n8n_mcp_token
}

# One single-server portal per service → one Claude.ai connector each.
resource "cloudflare_zero_trust_access_ai_controls_mcp_portal" "greenhouse" {
  account_id = var.cloudflare_account_id
  id         = "greenhouse-mcp-portal"
  name       = "Greenhouse"
  hostname   = "greenhouse-mcp.${var.zone_name}"

  servers = [
    { server_id = cloudflare_zero_trust_access_ai_controls_mcp_server.greenhouse.id },
  ]
}
# … firefly-mcp.${zone} and n8n-mcp.${zone} portals identical, one server each.
```

A self-hosted Access application + email policy on each
`*-mcp.${var.zone_name}` hostname (same pattern as the existing services)
provides the user-identity gate that Claude satisfies via OAuth. The three
`auth_credentials` are new sensitive tfvars, sourced from the Swarm secrets
that already exist.

---

## 5. Open items to resolve during implementation

1. **Outer CF Access on the upstream paths.** The three upstream hostnames are
   themselves behind CF Access. Confirm how the portal's outbound connection
   passes that outer gate — likely via **auth delegation / linked Access
   application** (Cloudflare-hosted origins in the same account), otherwise the
   portal connection would hit the Access challenge. If delegation is not
   available on-plan, fall back to a path-scoped **service-token bypass** that
   Cloudflare presents on the portal→upstream hop. Needs a live test.
2. **n8n MCP Server Trigger.** Confirm a workflow with an MCP Server Trigger
   node is actually live at `/mcp-server` and retrieve its bearer token.
3. **Plan availability.** Confirm MCP Server Portals are enabled on the
   account's Cloudflare One plan (GA, but a Zero Trust feature).
4. **Claude ↔ CF Access OAuth.** Verify the live connect: Claude requires PKCE
   S256 + DCR, which CF Access managed OAuth should satisfy.
5. **Tool-count / context.** Three servers expose many tools; use the portal's
   per-server tool curation + context optimization to keep Claude's context lean.

---

## 6. Why not the alternatives

- **Cloudflare Worker + `workers-oauth-provider`** (a hand-written OAuth proxy
  that injects the bearers): more flexible, but it is code + secrets + a deploy
  pipeline to maintain, and it duplicates what the managed portal does. Keep as
  a fallback only if portals are unavailable on-plan or a custom transform is
  needed.
- **Authless connector + nginx-injected bearer:** unsafe here — once the bearer
  is injected server-side, the endpoint's only gate is whoever finds the URL.
  An OAuth/Access gate is mandatory.
- **Make each app a full OAuth resource server:** most work, no benefit over the
  portal.

---

## 7. Sources

- Claude — [building custom connectors via remote MCP](https://support.claude.com/en/articles/11503834-build-custom-connectors-via-remote-mcp-servers) ·
  [connector authentication](https://claude.com/docs/connectors/building/authentication)
- Anthropic — [issue #110 (custom headers, closed/not planned)](https://github.com/anthropics/claude-ai-mcp/issues/110) ·
  [#112 (bearer token)](https://github.com/anthropics/claude-ai-mcp/issues/112)
- Cloudflare — [MCP server portals](https://developers.cloudflare.com/cloudflare-one/access-controls/ai-controls/mcp-portals/) ·
  [announcement](https://blog.cloudflare.com/zero-trust-mcp-server-portals/) ·
  [portals GA changelog](https://developers.cloudflare.com/changelog/post/2025-08-26-mcp-server-portals/) ·
  [linked self-hosted apps](https://developers.cloudflare.com/cloudflare-one/access-controls/ai-controls/linked-apps/)
- Terraform — `cloudflare_zero_trust_access_ai_controls_mcp_portal`,
  `cloudflare_zero_trust_access_ai_controls_mcp_server`
  (`cloudflare/cloudflare ~> 5.11`)
- n8n — [MCP Server Trigger node](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-langchain.mcptrigger/)
</content>
</invoke>
