# 📢 ntfy

> Self-hosted push notification service

**URL**: `https://ntfy.giocaizzi.xyz` (public via Cloudflare Tunnel, no CF Access — ntfy auth is the gate) · `https://ntfy.home` (LAN)

---

## 🚀 Quick Start

1. Deploy via Portainer → Swarm mode
2. Create admin user via CLI (see below)
3. Phone app: server `https://ntfy.giocaizzi.xyz`, log in as admin, subscribe to the [alert topics](#-alert-topics)

---

## 📦 Architecture

| Container | Image | Purpose |
|-----------|-------|---------|
| ntfy | `binwiederhier/ntfy:v2` | Notification server |

---

## 🔐 Secrets

No deployment secrets required. Users created via CLI after deployment.

---

## ⚙️ Configuration

Main config: `server.yml` (mounted as Swarm config)

| Setting | Value | Purpose |
|---------|-------|---------|
| `default-access` | `deny-all` | Require authentication |
| `behind-proxy` | `true` | Correct rate limiting |
| `cache-duration` | `24h` | Message retention |
| `attachment-total-size-limit` | `1G` | Max attachment cache |
| `attachment-file-size-limit` | `15M` | Per-file limit |

iOS support via upstream forwarding to ntfy.sh for APNS.

---

## 👤 User Management

### Create Admin User

```bash
ssh pi@pi.local
docker exec -it $(docker ps -qf name=ntfy_app) /bin/sh

# Inside container
ntfy user add --role=admin admin
ntfy token add admin  # Optional: create API token
```

### Add Regular Users

```bash
ntfy user add myuser
```

### Declarative Users (GitOps)

Bcrypt hashes are **safe to commit** (one-way, not reversible).

```bash
# Generate bcrypt hash
docker run --rm -it binwiederhier/ntfy user hash
# Enter password → outputs $2a$10$...
```

Uncomment in `server.yml`:
```yaml
auth-users:
  - "admin:$2a$10$YOUR_HASH:admin"
  - "user:$2a$10$HASH:user"
```

> ⚠️ **Never commit access tokens** (`tk_...`) — they are bearer credentials.

---

## 🔒 Access Control

```bash
# Grant topic access
ntfy access myuser alerts rw      # read-write
ntfy access myuser logs ro        # read-only
ntfy access everyone public ro    # anonymous read

# UnifiedPush support
ntfy access everyone "up*" write
```

---

## 🚨 Alert Topics

| Topic | Publisher | Token stored as (Secrets Manager) |
|-------|-----------|-----------------------------------|
| `grafana` | Grafana webhook (`?template=grafana`) | `observability_ntfy_token` |
| `netdata` | Netdata `health_alarm_notify.conf` (critical only) | `infra_ntfy_token` |

Both publish as user `alerts` (write-only), one token per source so each can be revoked alone:

```bash
ntfy user add alerts
ntfy access alerts grafana wo
ntfy access alerts netdata wo
ntfy token add --label grafana alerts
ntfy token add --label netdata alerts
```

---

## 📖 Usage Examples

### Publish (authenticated)
```bash
curl -u admin:PASSWORD \
  -d "Hello from ntfy!" \
  https://ntfy.home/alerts
```

### Subscribe
```bash
curl -u admin:PASSWORD \
  -s https://ntfy.home/alerts/json
```

### With Access Token
```bash
curl -H "Authorization: Bearer tk_..." \
  -d "Token auth message" \
  https://ntfy.home/alerts
```

---

## 💾 Volumes

| Volume | Purpose |
|--------|---------|
| `ntfy_cache` | Message cache, attachments |
| `ntfy_data` | User/auth database |
