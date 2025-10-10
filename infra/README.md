# Infrastructure Stack

## Services

**Nginx Reverse Proxy** (`nginx:alpine`)
- SSL termination and routing for all services
- Rate limiting and security headers
- WebSocket support for Portainer/N8N

**Portainer CE** (`portainer/portainer-ce:latest`)
- Docker management UI at `https://portainer.local`
- Resource limited (512MB RAM max)
- Read-only Docker socket access

**Cloudflare Tunnel** (`cloudflare/cloudflared:latest`)
- Secure external access without port forwarding
- Requires `CLOUDFLARED_TOKEN` environment variable

## Configuration

See [`.env.example`](./.env.example) for all environment variables.


## Nginx SSL Setup

**SSL Setup**:
```bash
cd nginx && ./generate-ssl.sh
```

Add to `/etc/hosts`:
```
127.0.0.1 portainer.local <other_services>.local
```

## Deployment

> *Deploy this stack first* - other services depend on the networks created here.

**Portainer**: *Recommended*, use [Portainer](../docs/PORTAINER.md)
**Manual**: with docker CLI `docker-compose up -d`
