# Security

## Security Features

- Zero-trust external access via Cloudflare
- Network segmentation between services
- Authentication required for all services
- HTTPS-only with nginx SSL termination
- Read-only Docker socket mounts where possible

## Zero-Trust Architecture

The architecture follows a zero-trust model with [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/tunnel-guide/) providing secure access without exposing ports directly.

```
Internet → Cloudflare Tunnel → Nginx Proxy → Services
```

## Docker Network Segmentation

Docker services are isolated in separate networks, connected only via nginx proxy:

*Infrastructure*:
- `rp5_public` (nginx frontend)
- `rp5_infra` (infrastructure internal) 

*Service-specific*:
- `rp5_n8n` (N8N isolated)
- `rp5_ollama` (Ollama isolated)

## Authentication
All services require authentication:
- Portainer: admin user login (set via Portainer UI on first access)
- N8N: HTTP Basic Auth (set via `N8N_BASIC_AUTH_PASSWORD`)
- Ollama: API key (set via `OLLAMA_API_KEY`)