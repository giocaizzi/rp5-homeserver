# ============================================================================
# Cloudflare Variables
# ============================================================================

variable "cloudflare_api_token" {
  description = "Cloudflare API token with necessary permissions"
  type        = string
  sensitive   = true
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID"
  type        = string
  sensitive   = true
}

variable "zone_name" {
  description = "Cloudflare zone name"
  type        = string
  // example.com
}

variable "zone_id" {
  description = "Zone ID of domain"
  type        = string
}

variable "tunnel_secret" {
  description = "Base64 encoded secret for the tunnel"
  type        = string
  sensitive   = true
  # weird: fails TODO: investigate
  # validation {
  #   condition     = can(base64decode(var.tunnel_secret))
  #   error_message = "Tunnel secret must be a valid base64 encoded string."
  # }
}

# ---- Optional ----

variable "n8n_users" {
  description = "List of email addresses allowed to access n8n"
  type        = list(string)
  default     = []
}

# ============================================================================
# GCP Variables
# ============================================================================

variable "gcp_project_id" {
  description = "GCP project ID"
  type        = string
}

variable "gcp_region" {
  description = "GCP region for resources"
  type        = string
  default     = "europe-west1"
}

variable "gcp_backup_bucket_name" {
  description = "Name of the GCS bucket for backups (must be globally unique)"
  type        = string
}

variable "allowed_ips" {
  description = "List of IP addresses/CIDR ranges allowed to access the backup bucket"
  type        = list(string)
  default     = []
  # Example: ["1.2.3.4/32", "5.6.7.0/24"]
}

variable "backup_retention_days" {
  description = "Number of days to retain backup files in GCS bucket before automatic deletion. Set to 0 to disable GCS lifecycle deletion and rely on Backrest's retention logic only."
  type        = number
  default     = 0 # 0 = disabled, rely on Backrest retention
  validation {
    condition     = var.backup_retention_days >= 0
    error_message = "backup_retention_days must be 0 (disabled) or a positive number of days."
  }
}