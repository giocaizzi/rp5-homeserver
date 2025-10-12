# Infrastructure Stack

> *Deploy this stack first* - other services depend on the networks created here.

## Network Architecture

**Created Networks:**
- `rp5_public` - Shared network for nginx ↔ service communication
- `rp5_infra` - Internal infrastructure network

**Service Integration:**
Services join `rp5_public` network to enable nginx routing without exposing ports directly.

```
Internet → Nginx (rp5_public) → Services (rp5_public + private networks)
```

## Services

**Nginx Reverse Proxy** (`nginx:alpine`)
- SSL termination and routing for all services
- Rate limiting and security headers
- WebSocket support for Portainer/N8N

**Portainer EE** (`portainer/portainer-ee:latest`)
- Docker management UI at `https://portainer.local`
- Business Edition with advanced features
- Resource limited (256MB RAM max)
- Read-only Docker socket access

> Using Business Edition for enhanced stack management capabilities.
> Get a free license (less than 3 nodes) at [Portainer](https://www.portainer.io/).

**Cloudflare Tunnel** (`cloudflare/cloudflared:latest`)
- Secure external access without port forwarding
- Requires `CLOUDFLARED_TOKEN` environment variable

**Netdata Monitoring** (`netdata/netdata:latest`)
- Real-time system monitoring at `https://netdata.local`
- Performance metrics, alerts, and dashboards
- Integrated with host system via bind mounts

## Volumes & Data

**Named Volumes:**
- `portainer_data` - Portainer configuration and stacks
- `netdata_cache` - Monitoring metrics cache
- `netdata_config` - Custom monitoring configuration
- `netdata_lib` - Monitoring runtime data

## Configuration

See [`.env.example`](./.env.example) for all environment variables.


## Nginx Post-Setup

### Generate certificates locally

SSL Certificates must be present in `./nginx/ssl` before starting the stack.

See [SSL Generation Instructions](../docs/setup.md#1-infrastructure-stack).

### Update hostsfile

In order to pass `nginx` hostname resolution, add to your local `/etc/hosts` file:

```
192.168.x.x portainer.local netdata.local <other_service>.local
```
