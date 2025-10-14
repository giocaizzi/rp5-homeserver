terraform {
  required_version = ">= 1.6"
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.11"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# # Data source for zone lookup
# data "cloudflare_zone" "main" {
#   zone_id = var.zone_id
#   # filter = {
#   #   name = var.zone_name
#   # }
# }

# Create the tunnel
resource "cloudflare_zero_trust_tunnel_cloudflared" "homeserver" {
  account_id    = var.cloudflare_account_id
  name          = "rp5-homeserver"
  config_src    = "cloudflare"
  tunnel_secret = var.tunnel_secret
}

# Reads the token used to run the tunnel on the server.
data "cloudflare_zero_trust_tunnel_cloudflared_token" "tunnel_token" {
  account_id   = var.cloudflare_account_id
  tunnel_id   = cloudflare_zero_trust_tunnel_cloudflared.homeserver.id
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

# Configures tunnel with a published application for clientless access.
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "tunnel_config" {
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.homeserver.id
  account_id = var.cloudflare_account_id
  config = {
    ingress = [
      {
        hostname = "n8n.${var.zone_name}"
        service  = "http://nginx:443"
      },
      {
        service = "http_status:404"
      }
    ]
  }
}

# Creates a reusable Access policy.
resource "cloudflare_zero_trust_access_policy" "n8n_users" {
  account_id = var.cloudflare_account_id
  name       = "n8n-users"
  decision   = "allow"
  include = [
    for email in var.users : { email = { email = email } }
    # {
    #   email_domain = {
    #     domain = "@example.com"
    #   }
    # }
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
