# ============================================================================
# WAF custom rules (Free plan: 5 rules, no regex, no Log action)
# ============================================================================
# One ruleset per phase per zone: every custom rule lives in this resource.
# Runs before Access, so it sees unauthenticated traffic and Worker/Anthropic calls alike.
# Rate limiting is not managed here: the single Free http_ratelimit slot is taken
# by a dashboard-managed rule ("Leaked credential check").

resource "cloudflare_ruleset" "custom" {
  zone_id = var.zone_id
  name    = "Custom rules"
  kind    = "zone"
  phase   = "http_request_firewall_custom"

  rules = [
    {
      # R1: scanner and probe paths on every host. Never touches /.well-known,
      # /api/oidc/token, MCP or device paths.
      description = "R1 block scanner paths"
      action      = "block"
      enabled     = true
      expression = join(" or ", [
        "starts_with(http.request.uri.path, \"/wp-\")",
        "starts_with(http.request.uri.path, \"/.env\")",
        "starts_with(http.request.uri.path, \"/.git\")",
        "http.request.uri.path contains \"xmlrpc.php\"",
        "http.request.uri.path contains \"phpmyadmin\"",
        "starts_with(http.request.uri.path, \"/cgi-bin/\")",
      ])
    },
    {
      # R2: edge path allowlist on machine-only hosts. Block any path nginx would
      # 404 anyway (nginx `location` blocks). A new MCP path in nginx needs a
      # matching change here (docs/ci_cd.md, "adding a public service").
      # /cdn-cgi/ stays open for Access login on the owner-gated host.
      description = "R2 edge path allowlist on machine-only hosts"
      action      = "block"
      enabled     = true
      expression = join(" ", [
        "(",
        "(http.host eq \"otel.${var.zone_name}\" and not starts_with(http.request.uri.path, \"/v1/\"))",
        "or (http.host eq \"netdata-mcp.${var.zone_name}\" and http.request.uri.path ne \"/mcp\")",
        "or (http.host eq \"langfuse-mcp.${var.zone_name}\" and http.request.uri.path ne \"/api/public/mcp\")",
        "or (http.host eq \"mcp-stdio.${var.zone_name}\" and not ends_with(http.request.uri.path, \"/mcp\"))",
        ") and not starts_with(http.request.uri.path, \"/cdn-cgi/\")",
      ])
    },
    {
      # R3: n8n production webhooks (/webhook/) bypass Access (main.tf, n8n_webhook_policy),
      # so only Telegram's webhook networks may reach them. Ranges from
      # https://core.telegram.org/bots/webhooks (they say to recheck it when deliveries
      # stop). A non-Telegram webhook source needs its own allowance here.
      description = "R3 n8n webhooks from Telegram networks only"
      action      = "block"
      enabled     = true
      expression = join(" ", [
        "http.host eq \"n8n.${var.zone_name}\"",
        "and starts_with(http.request.uri.path, \"/webhook/\")",
        "and not ip.src in {149.154.160.0/20 91.108.4.0/22}",
      ])
    },
  ]
}
