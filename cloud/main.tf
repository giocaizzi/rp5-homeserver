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
    for email in var.n8n_users : { email = { email = email } }
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

  # Public access prevention
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

# IP-based access control via firewall rules
# This restricts access to the bucket from specific IP addresses
resource "google_storage_bucket_iam_member" "public_read" {
  count  = length(var.allowed_ips) > 0 ? 1 : 0
  bucket = google_storage_bucket.backup.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"

  condition {
    title       = "IP Whitelist"
    description = "Allow access only from whitelisted IPs"
    expression  = join(" || ", [for ip in var.allowed_ips : "inIpRange(origin.ip, '${ip}')"])
  }
}
