# Portainer

Deploy RP5 Home Server stacks via Portainer's remote repository feature.

## Setup

**Add Repository** in Portainer:
- URL: `https://github.com/giocaizzi/rp5-homeserver`
- Branch: `refs/heads/main`
- Authentication: Configure if private repo

## Deployment Order

> ⚠️ **Critical**: Infrastructure stack first, then services.

### 1. Infrastructure Stack

Deploy `infra` stack first.

Enter the host via SSH or terminal and then run:
```bash
cd /path/to/infra
CLOUDFLARED_TOKEN="your-cloudflared-token" docker compose up -d
```

See [infra README](../infra/README.md) for details.

### 2. Deploy services

Deploy each service stack after infrastructure via Portainer.
See [How to add a service](./services.md).

## NGINX Post-Deployment

After deploying the infrastructure stack, set up SSL in order to enable HTTPS for all services and hostnames for local access.

### SSL Setup

```bash
cd /path/to/nginx && ./generate-ssl.sh
```

### Hosts file

Modify the host file `/etc/hosts`:
```
127.0.0.1 portainer.local n8n.local ollama.local
```

**Access URLs**:
- Portainer: `https://portainer.local`
- N8N: `https://n8n.local` (basic auth required)
- Ollama: `https://ollama.local` (API)