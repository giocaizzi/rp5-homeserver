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

  variable "users" {
    description = "List of email addresses allowed to access n8n"
    type        = list(string)
    default     = []
  }