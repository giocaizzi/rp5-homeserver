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
}

variable "zone_name" {
  description = "Cloudflare zone name (sensitive: keeps the domain out of public plan logs and PR comments)"
  type        = string
  sensitive   = true
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
  description = "List of email addresses allowed to access N8N"
  type        = list(string)
  default     = []
}

variable "portainer_users" {
  description = "List of email addresses allowed to access Portainer"
  type        = list(string)
  default     = []
  sensitive   = true
}

variable "backrest_users" {
  description = "List of email addresses allowed to access Backrest"
  type        = list(string)
  default     = []
  sensitive   = true
}

variable "firefly_users" {
  description = "List of email addresses allowed to access Firefly III"
  type        = list(string)
  default     = []
  sensitive   = true
}

variable "homepage_users" {
  description = "List of email addresses allowed to access Homepage"
  type        = list(string)
  default     = []
  sensitive   = true
}

variable "openclaw_users" {
  description = "List of email addresses allowed to access OpenClaw"
  type        = list(string)
  default     = []
  sensitive   = true
}

variable "grafana_users" {
  description = "List of email addresses allowed to access Grafana"
  type        = list(string)
  default     = []
  sensitive   = true
}

variable "greenhouse_users" {
  description = "List of email addresses allowed to access Greenhouse"
  type        = list(string)
  default     = []
  sensitive   = true
}

variable "code_users" {
  description = "List of email addresses allowed to access the Code dev environment (CloudCLI). Shell-equivalent access — keep this list minimal."
  type        = list(string)
  default     = []
  sensitive   = true
}

variable "crm_users" {
  description = "List of email addresses allowed to access the Twenty CRM UI (owner + sales staff)"
  type        = list(string)
  default     = []
  sensitive   = true
}

variable "calibre_users" {
  description = "List of email addresses allowed to access the Calibre-Web-Automated UI"
  type        = list(string)
  default     = []
  sensitive   = true
}

variable "miniflux_users" {
  description = "List of email addresses allowed to access the Miniflux UI"
  type        = list(string)
  default     = []
  sensitive   = true
}

variable "mcp_stdio_users" {
  description = "List of email addresses allowed through Access on mcp-stdio.<zone> outside the per-server service-token paths (owner only)"
  type        = list(string)
  default     = []
  sensitive   = true

  # Fail the plan rather than apply a host with no Access app: Access rejects a policy
  # with no include rule, and the DNS record and tunnel route would be created anyway.
  validation {
    condition     = length(var.mcp_stdio_users) > 0
    error_message = "Set the MCP_STDIO_USERS secret (JSON array of emails) on cloud-plan and cloud-production."
  }
}

variable "pocket_id_client_id" {
  description = "OIDC client ID of the Cloudflare Access client created in Pocket ID"
  type        = string
  sensitive   = true

  # An unset GitHub secret arrives as "": fail the plan instead of creating a broken login method.
  validation {
    condition     = length(var.pocket_id_client_id) > 0
    error_message = "Set the POCKET_ID_CLIENT_ID secret on cloud-plan and cloud-production (docs/pocket-id.md)."
  }
}

variable "pocket_id_client_secret" {
  description = "OIDC client secret of the Cloudflare Access client created in Pocket ID"
  type        = string
  sensitive   = true

  # An unset GitHub secret arrives as "": fail the plan instead of creating a broken login method.
  validation {
    condition     = length(var.pocket_id_client_secret) > 0
    error_message = "Set the POCKET_ID_CLIENT_SECRET secret on cloud-plan and cloud-production (docs/pocket-id.md)."
  }
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

variable "backup_retention_days" {
  description = "Number of days to retain backup files in GCS bucket before automatic deletion. Set to 0 to disable GCS lifecycle deletion and rely on Backrest's retention logic only."
  type        = number
  default     = 0 # 0 = disabled, rely on Backrest retention
  validation {
    condition     = var.backup_retention_days >= 0
    error_message = "backup_retention_days must be 0 (disabled) or a positive number of days."
  }
}