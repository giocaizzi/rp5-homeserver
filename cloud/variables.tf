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

variable "tunnel_secret" {
  description = "Base64 encoded secret for the tunnel"
  type        = string
  sensitive   = true
  validation {
    condition     = can(base64decode(var.tunnel_secret))
    error_message = "Tunnel secret must be a valid base64 encoded string."
  }
}

variable "owner_email" {
  description = "Owner email address for Cloudflare Access"
  type        = string
  // owner@example.com
}

variable "session_duration" {
  description = "Session duration for normal access"
  type        = string
  default     = "24h"
  validation {
    condition     = can(regex("^[0-9]+[hm]$", var.session_duration))
    error_message = "Session duration must be in format like '24h' or '30m'."
  }
}

// Emergency access variables

variable "enable_emergency_access" {
  description = "Enable emergency access policy"
  type        = bool
  default     = false
}

variable "emergency_emails" {
  description = "List of email addresses for emergency access"
  type        = list(string)
  default     = []
}

variable "emergency_email_domains" {
  description = "List of email domains allowed for emergency access"
  type        = list(string)
  default     = []
}

variable "emergency_session_duration" {
  description = "Session duration for emergency access"
  type        = string
  default     = "1h"
  validation {
    condition     = can(regex("^[0-9]+[hm]$", var.emergency_session_duration))
    error_message = "Emergency session duration must be in format like '1h' or '30m'."
  }
}
