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
  description = "List of email addresses allowed to access N8N"
  type        = list(string)
  default     = []
}

variable "portainer_users" {
  description = "List of email addresses allowed to access Portainer"
  type        = list(string)
  default     = []
}

variable "backrest_users" {
  description = "List of email addresses allowed to access Backrest"
  type        = list(string)
  default     = []
}

variable "firefly_users" {
  description = "List of email addresses allowed to access Firefly III"
  type        = list(string)
  default     = []
}

variable "homepage_users" {
  description = "List of email addresses allowed to access Homepage"
  type        = list(string)
  default     = []
}

variable "openclaw_users" {
  description = "List of email addresses allowed to access OpenClaw"
  type        = list(string)
  default     = []
}

variable "grafana_users" {
  description = "List of email addresses allowed to access Grafana"
  type        = list(string)
  default     = []
}

variable "greenhouse_users" {
  description = "List of email addresses allowed to access Greenhouse"
  type        = list(string)
  default     = []
}

# ---- Claude.ai MCP connectors ----
# App-level bearer tokens injected by Cloudflare (auth_type=bearer) on the
# portal->origin hop. Same secret values as the corresponding Swarm secrets:
# greenhouse_mcp_token, firefly_access_token (PAT), and the n8n MCP trigger token.

variable "greenhouse_mcp_token" {
  description = "Greenhouse MCP bearer token (matches Swarm secret greenhouse_mcp_token)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "firefly_mcp_token" {
  description = "Firefly III Personal Access Token used by its MCP endpoint (matches Swarm secret firefly_access_token)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "n8n_mcp_token" {
  description = "n8n MCP Server Trigger bearer token"
  type        = string
  sensitive   = true
  default     = ""
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