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
}

output "portainer_url" {
  description = "The public URL for Portainer"
  value       = "https://portainer.${var.zone_name}"
}

output "backrest_url" {
  description = "The public URL for Backrest"
  value       = "https://backrest.${var.zone_name}"
}

output "firefly_url" {
  description = "The public URL for Firefly III"
  value       = "https://firefly.${var.zone_name}"
}

output "openclaw_url" {
  description = "The public URL for OpenClaw"
  value       = "https://openclaw.${var.zone_name}"
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
# GitOps Webhook Outputs
# ============================================================================

output "github_webhook_client_id" {
  description = "Client ID for GitHub webhook service token"
  value       = cloudflare_zero_trust_access_service_token.github_webhook.client_id
}

output "github_webhook_client_secret" {
  description = "Client Secret for GitHub webhook service token"
  value       = cloudflare_zero_trust_access_service_token.github_webhook.client_secret
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

# ============================================================================
# OTLP ingestion outputs (CF Access bypass for otel.<zone>/v1/*)
# ============================================================================

output "otel_ingest_url" {
  description = "Public OTLP HTTP endpoint (set as OTEL_EXPORTER_OTLP_ENDPOINT)"
  value       = "https://otel.${var.zone_name}"
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