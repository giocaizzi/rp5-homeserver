# ============================================================================
# Cloudflare Outputs
# ============================================================================

output "tunnel_token" {
  description = "The token for the tunnel"
  value       = data.cloudflare_zero_trust_tunnel_cloudflared_token.tunnel_token.token
  sensitive   = true
}

output "tunnel_id" {
  description = "The ID of the created Cloudflare tunnel"
  value       = cloudflare_zero_trust_tunnel_cloudflared.homeserver.id
}

output "n8n_url" {
  description = "The public URL for N8N"
  value       = "https://n8n.${var.zone_name}"
  sensitive   = true
}

output "portainer_url" {
  description = "The public URL for Portainer"
  value       = "https://portainer.${var.zone_name}"
  sensitive   = true
}

output "backrest_url" {
  description = "The public URL for Backrest"
  value       = "https://backrest.${var.zone_name}"
  sensitive   = true
}

output "firefly_url" {
  description = "The public URL for Firefly III"
  value       = "https://firefly.${var.zone_name}"
  sensitive   = true
}

output "openclaw_url" {
  description = "The public URL for OpenClaw"
  value       = "https://openclaw.${var.zone_name}"
  sensitive   = true
}

output "grafana_url" {
  description = "The public URL for Grafana"
  value       = "https://grafana.${var.zone_name}"
  sensitive   = true
}

output "ntfy_url" {
  description = "The public URL for ntfy"
  value       = "https://ntfy.${var.zone_name}"
  sensitive   = true
}

output "greenhouse_url" {
  description = "The public URL for Greenhouse"
  value       = "https://greenhouse.${var.zone_name}"
  sensitive   = true
}

output "code_url" {
  description = "The public URL for the Code dev environment (CloudCLI)"
  value       = "https://code.${var.zone_name}"
  sensitive   = true
}

output "crm_url" {
  description = "The public URL for Twenty CRM (SERVER_URL)"
  value       = "https://crm.${var.zone_name}"
  sensitive   = true
}

output "calibre_url" {
  description = "The public URL for Calibre-Web-Automated"
  value       = "https://calibre.${var.zone_name}"
  sensitive   = true
}

# ============================================================================
# GCP Outputs
# ============================================================================

output "backup_bucket_name" {
  description = "Name of the backup GCS bucket"
  value       = google_storage_bucket.backup.name
}

output "backup_bucket_url" {
  description = "URL of the backup GCS bucket"
  value       = google_storage_bucket.backup.url
}

output "backup_service_account_email" {
  description = "Email of the backup service account"
  value       = google_service_account.backup.email
}

output "backup_service_account_key" {
  description = "Base64 encoded service account key JSON (save this securely)"
  value       = google_service_account_key.backup_key.private_key
  sensitive   = true
}

# ============================================================================
# Claude Code MCP Outputs (per-endpoint, isolated blast radius)
# ============================================================================

output "claude_n8n_mcp_client_id" {
  description = "Client ID for the n8n MCP service token (CF-Access-Client-Id)"
  value       = cloudflare_zero_trust_access_service_token.claude_n8n_mcp.client_id
}

output "claude_n8n_mcp_client_secret" {
  description = "Client Secret for the n8n MCP service token (CF-Access-Client-Secret)"
  value       = cloudflare_zero_trust_access_service_token.claude_n8n_mcp.client_secret
  sensitive   = true
}

output "claude_firefly_mcp_client_id" {
  description = "Client ID for the Firefly III MCP service token (CF-Access-Client-Id)"
  value       = cloudflare_zero_trust_access_service_token.claude_firefly_mcp.client_id
}

output "claude_firefly_mcp_client_secret" {
  description = "Client Secret for the Firefly III MCP service token (CF-Access-Client-Secret)"
  value       = cloudflare_zero_trust_access_service_token.claude_firefly_mcp.client_secret
  sensitive   = true
}

output "claude_greenhouse_mcp_client_id" {
  description = "Client ID for the greenhouse MCP service token (CF-Access-Client-Id)"
  value       = cloudflare_zero_trust_access_service_token.claude_greenhouse_mcp.client_id
}

output "claude_greenhouse_mcp_client_secret" {
  description = "Client Secret for the greenhouse MCP service token (CF-Access-Client-Secret)"
  value       = cloudflare_zero_trust_access_service_token.claude_greenhouse_mcp.client_secret
  sensitive   = true
}

output "external_crm_api_client_id" {
  description = "Client ID for the external backend -> Twenty CRM API service token (CF-Access-Client-Id)"
  value       = cloudflare_zero_trust_access_service_token.external_crm_api.client_id
}

output "external_crm_api_client_secret" {
  description = "Client Secret for the external backend -> Twenty CRM API service token (CF-Access-Client-Secret)"
  value       = cloudflare_zero_trust_access_service_token.external_crm_api.client_secret
  sensitive   = true
}

# ============================================================================
# OTLP ingestion outputs (CF Access bypass for otel.<zone>/v1/*)
# ============================================================================

output "otel_ingest_url" {
  description = "Public OTLP HTTP endpoint (set as OTEL_EXPORTER_OTLP_ENDPOINT)"
  value       = "https://otel.${var.zone_name}"
  sensitive   = true
}

output "otel_ingest_client_id" {
  description = "Client ID for the otel-ingest service token (CF-Access-Client-Id)"
  value       = cloudflare_zero_trust_access_service_token.otel_ingest.client_id
}

output "otel_ingest_client_secret" {
  description = "Client Secret for the otel-ingest service token (CF-Access-Client-Secret)"
  value       = cloudflare_zero_trust_access_service_token.otel_ingest.client_secret
  sensitive   = true
}

output "claude_grafana_mcp_client_id" {
  description = "Client ID for the Grafana MCP service token (CF-Access-Client-Id)"
  value       = cloudflare_zero_trust_access_service_token.claude_grafana_mcp.client_id
}

output "claude_grafana_mcp_client_secret" {
  description = "Client Secret for the Grafana MCP service token (CF-Access-Client-Secret)"
  value       = cloudflare_zero_trust_access_service_token.claude_grafana_mcp.client_secret
  sensitive   = true
}

output "claude_netdata_mcp_client_id" {
  description = "Client ID for the Netdata MCP service token (CF-Access-Client-Id)"
  value       = cloudflare_zero_trust_access_service_token.claude_netdata_mcp.client_id
}

output "claude_netdata_mcp_client_secret" {
  description = "Client Secret for the Netdata MCP service token (CF-Access-Client-Secret)"
  value       = cloudflare_zero_trust_access_service_token.claude_netdata_mcp.client_secret
  sensitive   = true
}

output "claude_portainer_mcp_client_id" {
  description = "Client ID for the Portainer MCP service token (CF-Access-Client-Id)"
  value       = cloudflare_zero_trust_access_service_token.claude_portainer_mcp.client_id
}

output "claude_portainer_mcp_client_secret" {
  description = "Client Secret for the Portainer MCP service token (CF-Access-Client-Secret)"
  value       = cloudflare_zero_trust_access_service_token.claude_portainer_mcp.client_secret
  sensitive   = true
}

output "claude_langfuse_mcp_client_id" {
  description = "Client ID for the Langfuse MCP service token (CF-Access-Client-Id)"
  value       = cloudflare_zero_trust_access_service_token.claude_langfuse_mcp.client_id
}

output "claude_langfuse_mcp_client_secret" {
  description = "Client Secret for the Langfuse MCP service token (CF-Access-Client-Secret)"
  value       = cloudflare_zero_trust_access_service_token.claude_langfuse_mcp.client_secret
  sensitive   = true
}
