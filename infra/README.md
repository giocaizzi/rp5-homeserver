# 🏗️ Infrastructure Stack

> Core infrastructure: reverse proxy, management UI, tunnel, monitoring, backups, dashboard

**Deploy first** — other stacks depend on networks created here.

---

## 🚀 Quick Start

```bash
# 1. Create the secrets in Secrets Manager (project rp5-homeserver, key infra_<file stem>)
# 2. Sync and deploy (writes ./secrets/ on the Pi from Secrets Manager)
BWS_ACCESS_TOKEN=<token> PI_SSH_USER=<user> DOMAIN=<domain> ./scripts/sync_infra.sh
```

---

## 📦 Architecture

| Container | Image | Purpose |
|-----------|-------|---------|
| nginx | `nginx` | Reverse proxy, SSL termination |
| portainer | `portainer/portainer-ee` | Docker management UI |
| management-mcp | `portainer/portainer-mcp` | Portainer MCP (full access) for the [mcp-connector](../workers/mcp-connector/README.md) |
| cloudflared | `cloudflare/cloudflared` | Secure tunnel (no port forwarding) |
| netdata | `netdata/netdata` | Real-time system monitoring |
| backrest | `garethgeorge/backrest` | Restic backup web UI; dumps the databases before each snapshot |
| docker-proxy | `wollomatic/socket-proxy` | Filtered Docker socket: exec into the DB tasks (Backrest) and prune (janitor) only |
| janitor | `docker` | Daily prune of stopped containers and unused images ([disk hygiene](../docs/monitoring.md#disk-hygiene)) |
| homepage | `ghcr.io/gethomepage/homepage` | Service dashboard |

Exact versions are pinned in `docker-compose.yml` and bumped by Dependabot PRs; see [docs/RUNBOOKS/image-updates.md](../docs/RUNBOOKS/image-updates.md).

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

File-based secrets in `./secrets/` on the Pi (gitignored). Source of truth: Secrets Manager project `rp5-homeserver`, key `infra_<file stem>`; `sync_infra.sh` writes the files (the Mac holds none).

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
| `portainer_mcp_auth_token` | `portainer_mcp_auth_token.txt` | Portainer MCP gate token (`openssl rand -hex 32`; key `infra_portainer_mcp_auth_token`) |
| `domain` | `domain.txt` | Production domain |
| `ntfy_token` | `ntfy_token.txt` | Netdata → ntfy publisher token |

```bash
# Generate a random password straight into Secrets Manager, then run sync_infra.sh
bws secret create infra_backrest_admin_password "$(openssl rand -base64 32)" <project-id>
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
3. Store it in Secrets Manager as `infra_portainer_api_key`, then run `sync_infra.sh`
4. Re-sync: `./scripts/sync_infra.sh`

### Portainer MCP

`management-mcp` serves MCP at `https://portainer.<domain>/mcp` (public host only), reached through the Worker connector. **Full Portainer access**: the Worker sends the gate token (`Authorization`, `UPSTREAM_BEARER`) and a dedicated Portainer access token (`X-Portainer-API-Key`, `UPSTREAM_EXTRA_HEADERS`). Create that token under a separate Portainer user so it can be revoked on its own. The upstream project is unsupported and its image minor must match Portainer's (`2.45` ↔ 2.45.x) — bump the tag with Portainer.

### Netdata MCP

Netdata ≥ 2.7.2 serves MCP natively on `/mcp`. `https://netdata-mcp.<domain>/mcp` is an MCP-only public host (nginx 404s everything else; the Netdata UI stays on `netdata.home`). Worker bearer = the agent's key in `/var/lib/netdata/mcp_dev_preview_api_key`.

### Cloudflared

Secure external access without port forwarding. Requires tunnel token from Cloudflare dashboard.

### Netdata

Real-time monitoring at `https://netdata.home`. Metrics, alerts, dashboards.

Critical health alarms (and their clear) push to ntfy topic `rp5` with tag `netdata` via `./netdata/health_alarm_notify.conf` (the tag is set through `curl_options` as an `X-Tags` header, because Netdata's ntfy sender hardcodes `Tags`). Re-check this override on every Netdata major upgrade (it depends on `alarm-notify.sh` internals). Test: `docker exec $(docker ps -qf name=infra_monitoring) /usr/libexec/netdata/plugins.d/alarm-notify.sh test`.

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
| `backrest_dumps` | Logical DB dumps written by `backrest/dump-dbs.sh` |
| `docker_proxy_socket` | Unix socket shared by docker-proxy, Backrest and janitor |

> Homepage uses bind-mounted `./homepage/` configs.
