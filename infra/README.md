# 🏗️ Infrastructure Stack

> Core infrastructure: reverse proxy, management UI, tunnel, monitoring, backups, dashboard

**Deploy first** — other stacks depend on networks created here.

---

## 🚀 Quick Start

```bash
# 1. Create secrets in ./secrets/
# 2. Sync and deploy
./scripts/sync_infra.sh
```

---

## 📦 Architecture

| Container | Image | Purpose |
|-----------|-------|---------|
| nginx | `nginx:alpine` | Reverse proxy, SSL termination |
| portainer | `portainer/portainer-ee:latest` | Docker management UI |
| cloudflared | `cloudflare/cloudflared:latest` | Secure tunnel (no port forwarding) |
| netdata | `netdata/netdata:latest` | Real-time system monitoring |
| backrest | `garethgeorge/backrest:latest` | Restic backup web UI |
| homepage | `ghcr.io/gethomepage/homepage:latest` | Service dashboard |

---

## 🌐 Networks

This stack creates shared networks for inter-stack communication:

| Network | Type | Purpose |
|---------|------|---------|
| `rp5_public` | overlay, external | nginx ↔ services routing |
| `rp5_infra` | overlay, internal | Infrastructure-only |

Services join `rp5_public` to receive nginx routing without exposing ports.

---

## 🔐 Secrets

File-based secrets in `./secrets/` (gitignored):

| Secret | File | Purpose |
|--------|------|---------|
| `ssl_cert` | `cert.pem` | SSL certificate |
| `ssl_key` | `key.pem` | SSL private key |
| `cloudflared_token` | `cloudflared_token.txt` | Tunnel token |
| `gcp_service_account` | `gcp_service_account.json` | GCS backup credentials |
| `portainer_api_key` | `portainer_api_key.txt` | Homepage widget |
| `backrest_admin_password` | `backrest_admin_password.txt` | Backrest + Homepage |
| `firefly_api_token` | `firefly_api_token.txt` | Homepage widget |
| `adguard_password` | `adguard_password.txt` | Homepage widget |
| `grafana_admin_password` | `grafana_admin_password.txt` | Homepage widget |
| `domain` | `domain.txt` | Production domain |

```bash
# Generate random passwords
openssl rand -base64 32 > ./secrets/backrest_admin_password.txt
```

---

## 📖 Services

### Nginx Reverse Proxy

SSL termination and routing for all `.home` domains. Config in `./nginx/nginx.conf`.

- Rate limiting and security headers
- WebSocket support (Portainer, n8n)
- Snippets: `proxy-headers.conf`, `ssl-params.conf`, `websocket-support.conf`

### Portainer

Docker management at `https://portainer.home`.

> Business Edition (free for ≤3 nodes) — get license at [portainer.io](https://www.portainer.io/)

**API Key Setup** (for Homepage widget):
1. Portainer → User account → API keys
2. Generate new key
3. Save to `./secrets/portainer_api_key.txt`
4. Re-sync: `./scripts/sync_infra.sh`

### Cloudflared

Secure external access without port forwarding. Requires tunnel token from Cloudflare dashboard.

### Netdata

Real-time monitoring at `https://netdata.home`. Metrics, alerts, dashboards.

### Backrest

Backup web UI at `https://backrest.home`. Automated incremental backups to GCS via restic.

See [docs/backup.md](../docs/backup.md) for setup.

### Homepage

Service dashboard at `https://homepage.home`. Config files in `./homepage/`.

---

## ⚙️ SSL Setup

Certificates required before first deployment:

```bash
# Generate self-signed (dev) or use Let's Encrypt/Cloudflare (prod)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout ./secrets/key.pem \
  -out ./secrets/cert.pem \
  -subj "/CN=*.home"
```

See [docs/setup.md](../docs/setup.md) for production SSL.

---

## 🌍 DNS Resolution

For `.home` domains to resolve:

**Recommended**: AdGuard DNS rewrites (network-wide)  
**Alternative**: Manual `/etc/hosts` entries per device

See [docs/dns.md](../docs/dns.md) for complete setup.

---

## 💾 Volumes

| Volume | Purpose |
|--------|---------|
| `portainer_data` | Portainer config, stacks |
| `netdata_cache` | Metrics cache |
| `netdata_config` | Custom config |
| `netdata_lib` | Runtime data |
| `backrest_data` | Backup metadata |
| `backrest_config` | Backup plans |
| `backrest_cache` | Restic cache |

> Homepage uses bind-mounted `./homepage/` configs.
