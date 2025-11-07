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
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# ============================================================================
# Cloudflare Resources
# ============================================================================

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}


# Create the tunnel
resource "cloudflare_zero_trust_tunnel_cloudflared" "homeserver" {
  account_id    = var.cloudflare_account_id
  name          = "rp5-homeserver"
  config_src    = "cloudflare"
  tunnel_secret = var.tunnel_secret
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

# Configures tunnel with a published application for clientless access.
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "tunnel_config" {
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.homeserver.id
  account_id = var.cloudflare_account_id
  config = {
    ingress = [
      {
        hostname = "n8n.${var.zone_name}"
        service  = "https://nginx:443"
        origin_request = {
          no_tls_verify      = true
          http_host_header   = "n8n.${var.zone_name}"
          origin_server_name = "n8n.${var.zone_name}"
        }
      },
      {
        hostname = "portainer.${var.zone_name}"
        service  = "https://nginx:443"
        origin_request = {
          no_tls_verify      = true
          http_host_header   = "portainer.${var.zone_name}"
          origin_server_name = "portainer.${var.zone_name}"
        }
      },
      {
        hostname = "backrest.${var.zone_name}"
        service  = "https://nginx:443"
        origin_request = {
          no_tls_verify      = true
          http_host_header   = "backrest.${var.zone_name}"
          origin_server_name = "backrest.${var.zone_name}"
        }
      },
      {
        hostname = "firefly.${var.zone_name}"
        service  = "https://nginx:443"
        origin_request = {
          no_tls_verify      = true
          http_host_header   = "firefly.${var.zone_name}"
          origin_server_name = "firefly.${var.zone_name}"
        }
      },
      {
        hostname = "homepage.${var.zone_name}"
        service  = "https://nginx:443"
        origin_request = {
          no_tls_verify      = true
          http_host_header   = "homepage.${var.zone_name}"
          origin_server_name = "homepage.${var.zone_name}"
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
    allowed_origins   = ["*"]  # GitHub webhook origins vary
    allow_credentials = false
    max_age          = 3600
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

# ============================================================================
# GCP Resources
# ============================================================================

provider "google" {
  project     = var.gcp_project_id
  region      = var.gcp_region
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