terraform {
  required_version = ">= 1.6"
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.11"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 7.7"
    }
  }
}

# ============================================================================
# Cloudflare Resources
# ============================================================================

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}


# Create the tunnel.
# tunnel_secret is intentionally ignored on update: the Cloudflare API never
# returns secret material on read, so without ignore_changes terraform would
# propose to rewrite it on every plan — and an actual write would invalidate
# the running cloudflared on the Pi.
resource "cloudflare_zero_trust_tunnel_cloudflared" "homeserver" {
  account_id    = var.cloudflare_account_id
  name          = "rp5-homeserver"
  config_src    = "cloudflare"
  tunnel_secret = var.tunnel_secret

  lifecycle {
    ignore_changes = [tunnel_secret]
  }
}

# Reads the token used to run the tunnel on the server.
data "cloudflare_zero_trust_tunnel_cloudflared_token" "tunnel_token" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.homeserver.id
}


# Creates the CNAME record that routes n8n.${var.zone_name} to the tunnel.
resource "cloudflare_dns_record" "n8n" {
  zone_id = var.zone_id
  name    = "n8n"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.homeserver.id}.cfargotunnel.com"
  type    = "CNAME"
  ttl     = 1
  proxied = true
}

# Creates the CNAME record that routes portainer.${var.zone_name} to the tunnel.
resource "cloudflare_dns_record" "portainer" {
  zone_id = var.zone_id
  name    = "portainer"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.homeserver.id}.cfargotunnel.com"
  type    = "CNAME"
  ttl     = 1
  proxied = true
}

# Creates the CNAME record that routes backrest.${var.zone_name} to the tunnel.
resource "cloudflare_dns_record" "backrest" {
  zone_id = var.zone_id
  name    = "backrest"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.homeserver.id}.cfargotunnel.com"
  type    = "CNAME"
  ttl     = 1
  proxied = true
}

# Creates the CNAME record that routes firefly.${var.zone_name} to the tunnel.
resource "cloudflare_dns_record" "firefly" {
  zone_id = var.zone_id
  name    = "firefly"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.homeserver.id}.cfargotunnel.com"
  type    = "CNAME"
  ttl     = 1
  proxied = true
}

# Creates the CNAME record that routes homepage.${var.zone_name} to the tunnel.
resource "cloudflare_dns_record" "homepage" {
  zone_id = var.zone_id
  name    = "homepage"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.homeserver.id}.cfargotunnel.com"
  type    = "CNAME"
  ttl     = 1
  proxied = true
}

# Creates the CNAME record that routes openclaw.${var.zone_name} to the tunnel.
resource "cloudflare_dns_record" "openclaw" {
  zone_id = var.zone_id
  name    = "openclaw"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.homeserver.id}.cfargotunnel.com"
  type    = "CNAME"
  ttl     = 1
  proxied = true
}

# Creates the CNAME record that routes grafana.${var.zone_name} to the tunnel.
resource "cloudflare_dns_record" "grafana" {
  zone_id = var.zone_id
  name    = "grafana"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.homeserver.id}.cfargotunnel.com"
  type    = "CNAME"
  ttl     = 1
  proxied = true
}

# Creates the CNAME record that routes greenhouse.${var.zone_name} to the tunnel.
resource "cloudflare_dns_record" "greenhouse" {
  zone_id = var.zone_id
  name    = "greenhouse"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.homeserver.id}.cfargotunnel.com"
  type    = "CNAME"
  ttl     = 1
  proxied = true
}

# Creates the CNAME record that routes otel.${var.zone_name} to the tunnel.
# OTLP HTTP ingestion: CF Access bypass on /v1/* + Alloy bearer auth.
resource "cloudflare_dns_record" "otel" {
  zone_id = var.zone_id
  name    = "otel"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.homeserver.id}.cfargotunnel.com"
  type    = "CNAME"
  ttl     = 1
  proxied = true
}

# Configures tunnel with a published application for clientless access.
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "tunnel_config" {
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.homeserver.id
  account_id = var.cloudflare_account_id
  config = {
    ingress = [
      {
        hostname = "n8n.${var.zone_name}"
        service  = "https://infra-proxy:443"
        origin_request = {
          no_tls_verify      = true
          http_host_header   = "n8n.${var.zone_name}"
          origin_server_name = "n8n.${var.zone_name}"
        }
      },
      {
        hostname = "portainer.${var.zone_name}"
        service  = "https://infra-proxy:443"
        origin_request = {
          no_tls_verify      = true
          http_host_header   = "portainer.${var.zone_name}"
          origin_server_name = "portainer.${var.zone_name}"
        }
      },
      {
        hostname = "backrest.${var.zone_name}"
        service  = "https://infra-proxy:443"
        origin_request = {
          no_tls_verify      = true
          http_host_header   = "backrest.${var.zone_name}"
          origin_server_name = "backrest.${var.zone_name}"
        }
      },
      {
        hostname = "firefly.${var.zone_name}"
        service  = "https://infra-proxy:443"
        origin_request = {
          no_tls_verify      = true
          http_host_header   = "firefly.${var.zone_name}"
          origin_server_name = "firefly.${var.zone_name}"
        }
      },
      {
        hostname = "homepage.${var.zone_name}"
        service  = "https://infra-proxy:443"
        origin_request = {
          no_tls_verify      = true
          http_host_header   = "homepage.${var.zone_name}"
          origin_server_name = "homepage.${var.zone_name}"
        }
      },
      {
        hostname = "openclaw.${var.zone_name}"
        service  = "https://infra-proxy:443"
        origin_request = {
          no_tls_verify      = true
          http_host_header   = "openclaw.${var.zone_name}"
          origin_server_name = "openclaw.${var.zone_name}"
        }
      },
      {
        hostname = "otel.${var.zone_name}"
        service  = "https://infra-proxy:443"
        origin_request = {
          no_tls_verify      = true
          http_host_header   = "otel.${var.zone_name}"
          origin_server_name = "otel.${var.zone_name}"
        }
      },
      {
        hostname = "grafana.${var.zone_name}"
        service  = "https://infra-proxy:443"
        origin_request = {
          no_tls_verify      = true
          http_host_header   = "grafana.${var.zone_name}"
          origin_server_name = "grafana.${var.zone_name}"
        }
      },
      {
        hostname = "greenhouse.${var.zone_name}"
        service  = "https://infra-proxy:443"
        origin_request = {
          no_tls_verify      = true
          http_host_header   = "greenhouse.${var.zone_name}"
          origin_server_name = "greenhouse.${var.zone_name}"
        }
      },
      {
        service = "http_status:404"
      }
    ]
  }
}

# Creates separate Access policies for each service.
resource "cloudflare_zero_trust_access_policy" "n8n_users" {
  account_id = var.cloudflare_account_id
  name       = "n8n-users"
  decision   = "allow"
  include = [
    for email in var.n8n_users : { email = { email = email } }
  ]
}

resource "cloudflare_zero_trust_access_policy" "portainer_users" {
  account_id = var.cloudflare_account_id
  name       = "portainer-users"
  decision   = "allow"
  include = [
    for email in var.portainer_users : { email = { email = email } }
  ]
}

resource "cloudflare_zero_trust_access_policy" "backrest_users" {
  account_id = var.cloudflare_account_id
  name       = "backrest-users"
  decision   = "allow"
  include = [
    for email in var.backrest_users : { email = { email = email } }
  ]
}

resource "cloudflare_zero_trust_access_policy" "firefly_users" {
  account_id = var.cloudflare_account_id
  name       = "firefly-users"
  decision   = "allow"
  include = [
    for email in var.firefly_users : { email = { email = email } }
  ]
}

resource "cloudflare_zero_trust_access_policy" "homepage_users" {
  account_id = var.cloudflare_account_id
  name       = "homepage-users"
  decision   = "allow"
  include = [
    for email in var.homepage_users : { email = { email = email } }
  ]
}

resource "cloudflare_zero_trust_access_policy" "openclaw_users" {
  account_id = var.cloudflare_account_id
  name       = "openclaw-users"
  decision   = "allow"
  include = [
    for email in var.openclaw_users : { email = { email = email } }
  ]
}

resource "cloudflare_zero_trust_access_policy" "grafana_users" {
  account_id = var.cloudflare_account_id
  name       = "grafana-users"
  decision   = "allow"
  include = [
    for email in var.grafana_users : { email = { email = email } }
  ]
}

resource "cloudflare_zero_trust_access_policy" "greenhouse_users" {
  account_id = var.cloudflare_account_id
  name       = "greenhouse-users"
  decision   = "allow"
  include = [
    for email in var.greenhouse_users : { email = { email = email } }
  ]
}

# ============================================================================
# Webhook Service Token and Bypass Policy for GitOps
# ============================================================================

# Create service token for GitHub webhook authentication
resource "cloudflare_zero_trust_access_service_token" "github_webhook" {
  account_id = var.cloudflare_account_id
  name       = "github-webhooks"
}

# Create bypass policy for webhook endpoints
resource "cloudflare_zero_trust_access_policy" "webhook_bypass" {
  account_id = var.cloudflare_account_id
  name       = "webhook-bypass"
  decision   = "bypass"

  include = [
    {
      service_token = {
        token_id = cloudflare_zero_trust_access_service_token.github_webhook.id
      }
    }
  ]
}

# Creates an Access application to control who can connect to the public hostname.
resource "cloudflare_zero_trust_access_application" "n8n_policy" {
  account_id = var.cloudflare_account_id
  type       = "self_hosted"
  name       = "n8n.${var.zone_name}"
  domain     = "n8n.${var.zone_name}"
  policies = [
    {
      id         = cloudflare_zero_trust_access_policy.n8n_users.id
      precedence = 1
    }
  ]
}

# Portainer access application with webhook bypass support
resource "cloudflare_zero_trust_access_application" "portainer_policy" {
  account_id       = var.cloudflare_account_id
  type             = "self_hosted"
  name             = "portainer.${var.zone_name}"
  domain           = "portainer.${var.zone_name}"
  session_duration = "24h"

  # Enable CORS for webhook requests
  cors_headers = {
    allowed_methods   = ["GET", "POST", "OPTIONS"]
    allowed_origins   = ["*"] # GitHub webhook origins vary
    allow_credentials = false
    max_age           = 3600
  }

  policies = [
    # Webhook bypass policy (highest precedence) - allows service tokens to bypass auth
    {
      id         = cloudflare_zero_trust_access_policy.webhook_bypass.id
      precedence = 1
    },
    # Regular user access policy
    {
      id         = cloudflare_zero_trust_access_policy.portainer_users.id
      precedence = 2
    }
  ]
}

resource "cloudflare_zero_trust_access_application" "backrest_policy" {
  account_id = var.cloudflare_account_id
  type       = "self_hosted"
  name       = "backrest.${var.zone_name}"
  domain     = "backrest.${var.zone_name}"
  policies = [
    {
      id         = cloudflare_zero_trust_access_policy.backrest_users.id
      precedence = 1
    }
  ]
}

resource "cloudflare_zero_trust_access_application" "firefly_policy" {
  account_id = var.cloudflare_account_id
  type       = "self_hosted"
  name       = "firefly.${var.zone_name}"
  domain     = "firefly.${var.zone_name}"
  policies = [
    {
      id         = cloudflare_zero_trust_access_policy.firefly_users.id
      precedence = 1
    }
  ]
}

resource "cloudflare_zero_trust_access_application" "homepage_policy" {
  account_id = var.cloudflare_account_id
  type       = "self_hosted"
  name       = "homepage.${var.zone_name}"
  domain     = "homepage.${var.zone_name}"
  policies = [
    {
      id         = cloudflare_zero_trust_access_policy.homepage_users.id
      precedence = 1
    }
  ]
}

resource "cloudflare_zero_trust_access_application" "openclaw_policy" {
  account_id = var.cloudflare_account_id
  type       = "self_hosted"
  name       = "openclaw.${var.zone_name}"
  domain     = "openclaw.${var.zone_name}"
  policies = [
    {
      id         = cloudflare_zero_trust_access_policy.openclaw_users.id
      precedence = 1
    }
  ]
}

resource "cloudflare_zero_trust_access_application" "grafana_policy" {
  account_id = var.cloudflare_account_id
  type       = "self_hosted"
  name       = "grafana.${var.zone_name}"
  domain     = "grafana.${var.zone_name}"
  policies = [
    {
      id         = cloudflare_zero_trust_access_policy.grafana_users.id
      precedence = 1
    }
  ]
}

# greenhouse_policy gates the whole hostname (UI + JSON API + /mcp) on email.
# /mcp at the app level is independently bearer-gated (GREENHOUSE_MCP_TOKEN,
# fail-closed since v2.0.0), so public /mcp is double-gated. LAN MCP keeps
# using greenhouse.home (plain HTTP, no CF Access).
resource "cloudflare_zero_trust_access_application" "greenhouse_policy" {
  account_id = var.cloudflare_account_id
  type       = "self_hosted"
  name       = "greenhouse.${var.zone_name}"
  domain     = "greenhouse.${var.zone_name}"
  policies = [
    {
      id         = cloudflare_zero_trust_access_policy.greenhouse_users.id
      precedence = 1
    }
  ]
}

# ============================================================================
# Claude Code MCP — per-endpoint service tokens + path-scoped bypass apps
# ============================================================================
# One service token per MCP endpoint, so a leaked token for n8n cannot reach
# Firefly III's MCP (and vice versa). Each endpoint's app references only its
# own bypass policy. Application-layer auth (n8n MCP token / Firefly III PAT)
# remains the second factor on top of CF Access bypass.

# --- n8n MCP --------------------------------------------------------------

resource "cloudflare_zero_trust_access_service_token" "claude_n8n_mcp" {
  account_id = var.cloudflare_account_id
  name       = "claude-n8n-mcp"
}

resource "cloudflare_zero_trust_access_policy" "claude_n8n_mcp_bypass" {
  account_id = var.cloudflare_account_id
  name       = "claude-n8n-mcp-bypass"
  decision   = "bypass"

  include = [
    {
      service_token = {
        token_id = cloudflare_zero_trust_access_service_token.claude_n8n_mcp.id
      }
    }
  ]
}

# Path-scoped Access app: matches only https://n8n.<zone>/mcp-server*, so the
# service token cannot be used to reach the n8n UI (which stays gated by
# cloudflare_zero_trust_access_application.n8n_policy + n8n_users).
# CF Access matches the most-specific path first.
resource "cloudflare_zero_trust_access_application" "n8n_mcp_policy" {
  account_id = var.cloudflare_account_id
  type       = "self_hosted"
  name       = "n8n-mcp.${var.zone_name}"

  destinations = [
    {
      type = "public"
      uri  = "n8n.${var.zone_name}/mcp-server"
    }
  ]

  policies = [
    {
      id         = cloudflare_zero_trust_access_policy.claude_n8n_mcp_bypass.id
      precedence = 1
    },
    # Claude.ai connector: portal traverses Access via linked-app token.
    {
      id         = cloudflare_zero_trust_access_policy.n8n_mcp_linked.id
      precedence = 2
    }
  ]
}

# --- OTLP ingestion (Alloy) ----------------------------------------------
# Public OTLP HTTP endpoint. CF Access bypass is the OUTER gate (short-circuits
# CF's SSO so SDK clients can POST without a browser), Alloy's bearer auth on
# the OTLP HTTP receiver is the INNER gate (validates the actual identity).
# Two independent secrets — leaking one alone does not grant ingestion.

resource "cloudflare_zero_trust_access_service_token" "otel_ingest" {
  account_id = var.cloudflare_account_id
  name       = "otel-ingest"
}

resource "cloudflare_zero_trust_access_policy" "otel_ingest_bypass" {
  account_id = var.cloudflare_account_id
  name       = "otel-ingest-bypass"
  decision   = "bypass"

  include = [
    {
      service_token = {
        token_id = cloudflare_zero_trust_access_service_token.otel_ingest.id
      }
    }
  ]
}

# Path-scoped Access app: matches only https://otel.<zone>/v1/* (OTLP HTTP
# paths: /v1/traces, /v1/metrics, /v1/logs). Anything else on this hostname
# returns the default Access challenge — there is no UI to protect, but this
# narrows the blast radius if a token leaks.
resource "cloudflare_zero_trust_access_application" "otel_ingest_policy" {
  account_id = var.cloudflare_account_id
  type       = "self_hosted"
  name       = "otel-ingest.${var.zone_name}"

  destinations = [
    {
      type = "public"
      uri  = "otel.${var.zone_name}/v1/"
    }
  ]

  policies = [
    {
      id         = cloudflare_zero_trust_access_policy.otel_ingest_bypass.id
      precedence = 1
    }
  ]
}

# --- Firefly III MCP ------------------------------------------------------

resource "cloudflare_zero_trust_access_service_token" "claude_firefly_mcp" {
  account_id = var.cloudflare_account_id
  name       = "claude-firefly-mcp"
}

resource "cloudflare_zero_trust_access_policy" "claude_firefly_mcp_bypass" {
  account_id = var.cloudflare_account_id
  name       = "claude-firefly-mcp-bypass"
  decision   = "bypass"

  include = [
    {
      service_token = {
        token_id = cloudflare_zero_trust_access_service_token.claude_firefly_mcp.id
      }
    }
  ]
}

# Path-scoped Access app: matches only https://firefly.<zone>/api/v1/mcp*, so
# the service token cannot be used to reach the Firefly III web UI (which stays
# gated by the existing firefly Access app). CF Access matches the most-specific
# path first, so this takes precedence on /api/v1/mcp* requests.
resource "cloudflare_zero_trust_access_application" "firefly_mcp_policy" {
  account_id = var.cloudflare_account_id
  type       = "self_hosted"
  name       = "firefly-mcp.${var.zone_name}"

  destinations = [
    {
      type = "public"
      uri  = "firefly.${var.zone_name}/api/v1/mcp"
    }
  ]

  policies = [
    {
      id         = cloudflare_zero_trust_access_policy.claude_firefly_mcp_bypass.id
      precedence = 1
    },
    # Claude.ai connector: portal traverses Access via linked-app token.
    {
      id         = cloudflare_zero_trust_access_policy.firefly_mcp_linked.id
      precedence = 2
    }
  ]
}

# ============================================================================
# Claude.ai connectors — MCP Server Portals (OAuth, no custom headers)
# ============================================================================
# Claude.ai custom connectors authenticate ONLY via OAuth — the UI has no field
# for a bearer token or custom header (anthropics/claude-ai-mcp#110, closed
# "not planned"). The Claude Code MCP section above (service-token bypass +
# client-sent bearer) therefore does NOT work for Claude.ai; this is a separate,
# parallel path that leaves it untouched.
#
# Each MCP server gets its OWN single-server portal, so it shows up as a
# separate connector in Claude.ai (independently toggled, isolated — same
# blast-radius philosophy as the per-endpoint service tokens above).
#
# Per service:
#   1. DNS: <svc>-mcp.<zone> CNAME -> gateway.agents.cloudflare.com (proxied).
#      The portal is Cloudflare-hosted; it is NOT served by the tunnel/nginx.
#   2. mcp_server: registers the upstream endpoint. auth_type=bearer makes
#      Cloudflare inject the app token (Authorization: Bearer) itself, so no
#      nginx header injection and no client-sent headers are needed.
#   3. mcp_portal: single-server portal at the <svc>-mcp.<zone> hostname.
#   4. Access app on the portal hostname, reusing the service's existing user
#      policy — the OAuth/identity gate Claude satisfies on connect.
#   5. linked_app_token policy on the UPSTREAM Access app, authorizing the
#      portal to traverse the upstream's CF Access on the portal->origin hop.
#
# The `app_uid` in each *_mcp_linked policy must be the UID of the portal's
# self-hosted Access application (the `<svc>_mcp_portal` app's `id`, a UUID) —
# NOT the mcp_portal resource id string, which CF rejects with code 12130
# ("linked app must be an existing app"). See the linked-apps docs.
# https://developers.cloudflare.com/cloudflare-one/access-controls/ai-controls/linked-apps/

# --- Greenhouse connector --------------------------------------------------

resource "cloudflare_dns_record" "greenhouse_mcp" {
  zone_id = var.zone_id
  name    = "greenhouse-mcp"
  content = "gateway.agents.cloudflare.com"
  type    = "CNAME"
  ttl     = 1
  proxied = true
}

resource "cloudflare_zero_trust_access_ai_controls_mcp_server" "greenhouse" {
  account_id       = var.cloudflare_account_id
  id               = "greenhouse-mcp"
  name             = "Greenhouse"
  auth_type        = "bearer"
  hostname         = "https://greenhouse.${var.zone_name}/mcp"
  auth_credentials = var.greenhouse_mcp_token
  updated_tools    = []
  updated_prompts  = []
}

resource "cloudflare_zero_trust_access_ai_controls_mcp_portal" "greenhouse" {
  account_id = var.cloudflare_account_id
  id         = "greenhouse-mcp-portal"
  name       = "Greenhouse"
  hostname   = "greenhouse-mcp.${var.zone_name}"

  servers = [
    { server_id = cloudflare_zero_trust_access_ai_controls_mcp_server.greenhouse.id, updated_tools = [], updated_prompts = [] },
  ]
}

# OAuth/identity gate on the portal hostname (reuses greenhouse_users).
resource "cloudflare_zero_trust_access_application" "greenhouse_mcp_portal" {
  account_id = var.cloudflare_account_id
  type       = "self_hosted"
  name       = "greenhouse-mcp.${var.zone_name}"
  domain     = "greenhouse-mcp.${var.zone_name}"
  policies = [
    {
      id         = cloudflare_zero_trust_access_policy.greenhouse_users.id
      precedence = 1
    }
  ]
}

# Portal->origin traversal. greenhouse.<zone>/mcp is email-gated whole-host by
# greenhouse_policy; this path-scoped app allows EITHER a logged-in user OR the
# linked portal, preserving the browser double-gating (email + bearer) while
# letting the portal reach /mcp.
resource "cloudflare_zero_trust_access_policy" "greenhouse_mcp_linked" {
  account_id = var.cloudflare_account_id
  name       = "greenhouse-mcp-linked"
  decision   = "allow"
  include = [
    {
      linked_app_token = {
        app_uid = cloudflare_zero_trust_access_application.greenhouse_mcp_portal.id
      }
    }
  ]
}

resource "cloudflare_zero_trust_access_application" "greenhouse_mcp_upstream" {
  account_id = var.cloudflare_account_id
  type       = "self_hosted"
  name       = "greenhouse-mcp-upstream.${var.zone_name}"

  destinations = [
    {
      type = "public"
      uri  = "greenhouse.${var.zone_name}/mcp"
    }
  ]

  policies = [
    {
      id         = cloudflare_zero_trust_access_policy.greenhouse_mcp_linked.id
      precedence = 1
    },
    {
      id         = cloudflare_zero_trust_access_policy.greenhouse_users.id
      precedence = 2
    }
  ]
}

# --- Firefly III connector -------------------------------------------------

resource "cloudflare_dns_record" "firefly_mcp" {
  zone_id = var.zone_id
  name    = "firefly-mcp"
  content = "gateway.agents.cloudflare.com"
  type    = "CNAME"
  ttl     = 1
  proxied = true
}

resource "cloudflare_zero_trust_access_ai_controls_mcp_server" "firefly" {
  account_id       = var.cloudflare_account_id
  id               = "firefly-mcp"
  name             = "Firefly III"
  auth_type        = "bearer"
  hostname         = "https://firefly.${var.zone_name}/api/v1/mcp"
  auth_credentials = var.firefly_mcp_token
  updated_tools    = []
  updated_prompts  = []
}

resource "cloudflare_zero_trust_access_ai_controls_mcp_portal" "firefly" {
  account_id = var.cloudflare_account_id
  id         = "firefly-mcp-portal"
  name       = "Firefly III"
  hostname   = "firefly-mcp.${var.zone_name}"

  servers = [
    { server_id = cloudflare_zero_trust_access_ai_controls_mcp_server.firefly.id, updated_tools = [], updated_prompts = [] },
  ]
}

resource "cloudflare_zero_trust_access_application" "firefly_mcp_portal" {
  account_id = var.cloudflare_account_id
  type       = "self_hosted"
  name       = "firefly-mcp.${var.zone_name}"
  domain     = "firefly-mcp.${var.zone_name}"
  policies = [
    {
      id         = cloudflare_zero_trust_access_policy.firefly_users.id
      precedence = 1
    }
  ]
}

# Portal->origin traversal for firefly.<zone>/api/v1/mcp. Added alongside the
# existing claude_firefly_mcp_bypass (Claude Code service token) on the same
# path-scoped upstream app, so both clients can reach the endpoint.
resource "cloudflare_zero_trust_access_policy" "firefly_mcp_linked" {
  account_id = var.cloudflare_account_id
  name       = "firefly-mcp-linked"
  decision   = "allow"
  include = [
    {
      linked_app_token = {
        app_uid = cloudflare_zero_trust_access_application.firefly_mcp_portal.id
      }
    }
  ]
}

# --- n8n connector ---------------------------------------------------------

resource "cloudflare_dns_record" "n8n_mcp" {
  zone_id = var.zone_id
  name    = "n8n-mcp"
  content = "gateway.agents.cloudflare.com"
  type    = "CNAME"
  ttl     = 1
  proxied = true
}

resource "cloudflare_zero_trust_access_ai_controls_mcp_server" "n8n" {
  account_id       = var.cloudflare_account_id
  id               = "n8n-mcp"
  name             = "n8n"
  auth_type        = "bearer"
  hostname         = "https://n8n.${var.zone_name}/mcp-server/http"
  auth_credentials = var.n8n_mcp_token
  updated_tools    = []
  updated_prompts  = []
}

resource "cloudflare_zero_trust_access_ai_controls_mcp_portal" "n8n" {
  account_id = var.cloudflare_account_id
  id         = "n8n-mcp-portal"
  name       = "n8n"
  hostname   = "n8n-mcp.${var.zone_name}"

  servers = [
    { server_id = cloudflare_zero_trust_access_ai_controls_mcp_server.n8n.id, updated_tools = [], updated_prompts = [] },
  ]
}

resource "cloudflare_zero_trust_access_application" "n8n_mcp_portal" {
  account_id = var.cloudflare_account_id
  type       = "self_hosted"
  name       = "n8n-mcp.${var.zone_name}"
  domain     = "n8n-mcp.${var.zone_name}"
  policies = [
    {
      id         = cloudflare_zero_trust_access_policy.n8n_users.id
      precedence = 1
    }
  ]
}

# Portal->origin traversal for n8n.<zone>/mcp-server. Added alongside the
# existing claude_n8n_mcp_bypass (Claude Code service token) on the same
# path-scoped upstream app.
resource "cloudflare_zero_trust_access_policy" "n8n_mcp_linked" {
  account_id = var.cloudflare_account_id
  name       = "n8n-mcp-linked"
  decision   = "allow"
  include = [
    {
      linked_app_token = {
        app_uid = cloudflare_zero_trust_access_application.n8n_mcp_portal.id
      }
    }
  ]
}

# ============================================================================
# GCP Resources
# ============================================================================

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

# GCS bucket for backups - Archive storage class for cost-effective storage
resource "google_storage_bucket" "backup" {
  name          = var.gcp_backup_bucket_name
  location      = var.gcp_region
  storage_class = "ARCHIVE" # Most cost-effective for infrequent access backups

  # Prevent accidental deletion
  force_destroy = false

  # Enable versioning for backup protection
  versioning {
    enabled = true
  }

  # Lifecycle rules for cost optimization (optional)
  # Only apply if backup_retention_days is set (> 0)
  # Otherwise rely on Backrest's internal retention logic
  dynamic "lifecycle_rule" {
    for_each = var.backup_retention_days > 0 ? [1] : []
    content {
      action {
        type = "Delete"
      }
      condition {
        age = var.backup_retention_days
      }
    }
  }

  # Uniform bucket-level access
  uniform_bucket_level_access = true

  # Public access prevention - enforced for maximum security
  public_access_prevention = "enforced"

  labels = {
    environment = "production"
    purpose     = "backup"
    managed_by  = "terraform"
  }
}

# Service account for backup operations
resource "google_service_account" "backup" {
  account_id   = "restic-backup"
  display_name = "Restic Backup Service Account"
  description  = "Service account for Restic/Backrest backup operations to GCS"
}

# IAM binding - Grant bucket admin to service account
resource "google_storage_bucket_iam_member" "backup_admin" {
  bucket = google_storage_bucket.backup.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.backup.email}"
}

# Create service account key
resource "google_service_account_key" "backup_key" {
  service_account_id = google_service_account.backup.name
}