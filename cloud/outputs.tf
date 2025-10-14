output "tunnel_token" {
  description = "The token for the tunnel"
#   sensitive = true
  value       = data.cloudflare_zero_trust_tunnel_cloudflared_token.tunnel_token.token

}

output "tunnel_id" {
  description = "The ID of the created Cloudflare tunnel"
  value       = cloudflare_zero_trust_tunnel_cloudflared.homeserver.id
}

output "n8n_url" {
  description = "The public URL for N8N"
  value       = "https://n8n.${var.zone_name}"
}