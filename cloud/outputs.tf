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