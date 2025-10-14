terraform {
  required_version = ">= 1.6"
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.43"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# Data sources to fetch existing resources
data "cloudflare_zone" "main" {
  name = var.zone_name
}

# Create the tunnel
resource "cloudflare_zero_trust_tunnel_cloudflared" "homeserver" {
  account_id = var.cloudflare_account_id
  name       = "rp5-homeserver"
  secret     = var.tunnel_secret
}

# tunnel configuration
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "homeserver" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.homeserver.id

  config {
    # Nginx proxy endpoint for all services
    ingress_rule {
      hostname = "n8n.${var.zone_name}"
      service  = "https://nginx:443"
      origin_request {
        http_host_header = "n8n.${var.zone_name}"
        no_happy_eyeballs = true
        keep_alive_timeout = "30s"
        keep_alive_connections = 10
        no_tls_verify = true  # Accept self-signed certificates
      }
    }

    # Default catch-all rule (required)
    ingress_rule {
      service = "http_status:404"
    }

    # Tunnel settings
    warp_routing {
      enabled = false
    }
  }
}

# DNS record for n8n subdomain
resource "cloudflare_record" "n8n" {
  zone_id = data.cloudflare_zone.main.id
  name    = "n8n"
  content   = cloudflare_zero_trust_tunnel_cloudflared.homeserver.cname
  type    = "CNAME"
  proxied = true
  comment = "N8N automation platform via Cloudflare Tunnel"
  tags    = ["homeserver"]
}

#  Zero Trust Access Application for N8N
resource "cloudflare_zero_trust_access_application" "n8n" {
  zone_id                   = data.cloudflare_zone.main.id
  name                      = "N8N Automation Platform"
  domain                    = "n8n.${var.zone_name}"
  type                      = "self_hosted"
  session_duration          = "24h"
  auto_redirect_to_identity = false

  cors_headers {
    allowed_methods = ["GET", "POST", "OPTIONS", "PUT", "DELETE", "PATCH"]
    allowed_origins = ["https://n8n.${var.zone_name}"]
    allow_credentials = true
    max_age = 300
  }

  app_launcher_visible = true
}

# Access Policy for N8N - Only allow owner
resource "cloudflare_access_policy" "n8n_owner_only" {
  application_id = cloudflare_zero_trust_access_application.n8n.id
  zone_id        = data.cloudflare_zone.main.id
  name           = "Owner Only Access"
  precedence     = 1
  decision       = "allow"

  include {
    email = [var.owner_email]
  }

  session_duration = var.session_duration
}

# Additional Access Policy for emergency access (conditional)
resource "cloudflare_access_policy" "n8n_emergency" {
  count = var.enable_emergency_access ? 1 : 0

  application_id = cloudflare_zero_trust_access_application.n8n.id
  zone_id        = data.cloudflare_zone.main.id
  name           = "Emergency Access"
  precedence     = 2
  decision       = "allow"

  include {
    email = var.emergency_emails
  }

  include {
    email_domain = var.emergency_email_domains
  }

  # Require additional verification for emergency access
  require {
    auth_method = "otp"
  }

  session_duration = var.emergency_session_duration
}

# Security settings for the zone
resource "cloudflare_zone_settings_override" "main_security" {
  zone_id = data.cloudflare_zone.main.id

  settings {
    # Security settings
    security_level = "medium"
    challenge_ttl  = 1800
    
    # SSL settings
    ssl                      = "strict"
    min_tls_version         = "1.2"
    tls_1_3                 = "on"
    automatic_https_rewrites = "on"
    
    # Performance settings
    minify {
      css  = "on"
      js   = "on"
      html = "on"
    }
    
    # Security headers
    security_header {
      enabled = true
      preload = true
      max_age = 31536000
      include_subdomains = true
      nosniff = true
    }
    
    # Browser check
    browser_check = "on"
  }
}