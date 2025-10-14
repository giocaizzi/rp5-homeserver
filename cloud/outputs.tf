output "tunnel_id" {
  description = "The ID of the created Cloudflare tunnel"
  value       = cloudflare_tunnel.homeserver.id
}

output "tunnel_cname" {
  description = "The CNAME for the tunnel"
  value       = cloudflare_tunnel.homeserver.cname
}

output "tunnel_token" {
  description = "The token for the tunnel (sensitive)"
  value       = cloudflare_tunnel.homeserver.tunnel_token
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

output "identity_provider_id" {
  description = "The ID of the Email OTP identity provider"
  value       = cloudflare_access_identity_provider.email_otp.id
}

output "emergency_policy_enabled" {
  description = "Whether emergency access policy is enabled"
  value       = var.enable_emergency_access
}