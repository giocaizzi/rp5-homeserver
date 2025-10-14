output "tunnel_id" {
  description = "The ID of the created Cloudflare tunnel"
  value       = cloudflare_zero_trust_tunnel_cloudflared.homeserver.id
}

output "tunnel_cname" {
  description = "The CNAME for the tunnel"
  value       = cloudflare_zero_trust_tunnel_cloudflared.homeserver.cname
}

output "tunnel_token" {
  description = "The token for the tunnel (sensitive)"
  value       = cloudflare_zero_trust_tunnel_cloudflared.homeserver.tunnel_token
  sensitive   = true
}

output "n8n_url" {
  description = "The public URL for N8N"
  value       = "https://n8n.${var.zone_name}"
}

output "access_application_id" {
  description = "The ID of the Cloudflare Access application for N8N"
  value       = cloudflare_access_application.n8n.id
}

output "emergency_policy_enabled" {
  description = "Whether emergency access policy is enabled"
  value       = var.enable_emergency_access
}