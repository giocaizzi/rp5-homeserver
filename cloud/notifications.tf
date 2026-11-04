# ============================================================================
# Cloudflare notifications (email)
# ============================================================================
# Dashboard-managed, deliberately not in code: DDoS Protection (dos_attack_l7),
# Expiring Service Token Alert (expiring_service_token_alert) and Leaked Service
# Token Alert (leaked_service_token_alert). Do not recreate them here.
# Email, not a webhook: a webhook to ntfy would be dead exactly when the tunnel is down.

resource "cloudflare_notification_policy" "tunnel_health" {
  account_id  = var.cloudflare_account_id
  name        = "Tunnel health"
  description = "Tunnel went down, degraded or recovered"
  alert_type  = "tunnel_health_event"
  enabled     = true

  mechanisms = {
    email = [{ id = var.alert_email }]
  }

  filters = {
    tunnel_id = [cloudflare_zero_trust_tunnel_cloudflared.homeserver.id]
  }
}

resource "cloudflare_notification_policy" "universal_ssl" {
  account_id  = var.cloudflare_account_id
  name        = "Universal SSL"
  description = "Universal SSL certificate issuance or renewal events"
  alert_type  = "universal_ssl_event_type"
  enabled     = true

  mechanisms = {
    email = [{ id = var.alert_email }]
  }
}

resource "cloudflare_notification_policy" "incident" {
  account_id  = var.cloudflare_account_id
  name        = "Cloudflare incidents"
  description = "Cloudflare status incidents"
  alert_type  = "incident_alert"
  enabled     = true

  mechanisms = {
    email = [{ id = var.alert_email }]
  }
}
