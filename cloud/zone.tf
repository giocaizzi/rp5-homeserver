# ============================================================================
# Zone settings, HSTS, DNSSEC, CAA
# ============================================================================
# Settings codify the live values so a dashboard click cannot silently
# downgrade them. security_level is intentionally not managed: it only toggles
# Under Attack mode now. Removing a resource leaves the live value untouched.

locals {
  zone_settings = {
    ssl                      = "strict"
    always_use_https         = "on"
    min_tls_version          = "1.2" # older e-readers
    tls_1_3                  = "on"  # TLS 1.3 without 0-RTT
    automatic_https_rewrites = "on"
    browser_check            = "on"
    rocket_loader            = "off"
    http3                    = "on"
    opportunistic_encryption = "on"
    privacy_pass             = "on"
    email_obfuscation        = "on"
    hotlink_protection       = "on"
    ip_geolocation           = "on"
  }
}

resource "cloudflare_zone_setting" "this" {
  for_each   = local.zone_settings
  zone_id    = var.zone_id
  setting_id = each.key
  value      = each.value
}

# HSTS: 6 months, no includeSubDomains, no preload.
resource "cloudflare_zone_setting" "security_header" {
  zone_id    = var.zone_id
  setting_id = "security_header"
  value = {
    strict_transport_security = {
      enabled            = true
      max_age            = 15552000
      include_subdomains = false
      nosniff            = true
      preload            = false
    }
  }
}

# DNSSEC: signing only. The DS record is added at the registrar by the owner
# (see docs/cloud.md, DNSSEC runbook).
resource "cloudflare_zone_dnssec" "this" {
  zone_id = var.zone_id
  status  = "active"
}

# CAA: Cloudflare adds its own Universal SSL CAs automatically once any CAA exists.
resource "cloudflare_dns_record" "caa_letsencrypt" {
  zone_id = var.zone_id
  name    = var.zone_name
  type    = "CAA"
  ttl     = 1
  data = {
    flags = 0
    tag   = "issue"
    value = "letsencrypt.org"
  }
}

resource "cloudflare_dns_record" "caa_google" {
  zone_id = var.zone_id
  name    = var.zone_name
  type    = "CAA"
  ttl     = 1
  data = {
    flags = 0
    tag   = "issue"
    value = "pki.goog"
  }
}
