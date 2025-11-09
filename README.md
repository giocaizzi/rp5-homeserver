# RP5 Home Server

Raspberry Pi 5 Docker Swarm-based home server.

## 🚀 Quick Start

1. Deploy the [infrastructure stack](infra/README.md) with Docker Swarm and [Portainer](./setup.md).
2. Then access Portainer at `https://portainer.home` to deploy desired services using swarm stacks.

## 🧩 Services

Applications available for deployment:

- **[N8N](./services/n8n/README.md)** - Workflow automation (`https://n8n.home`)
- **[Ollama](./services/ollama/README.md)** - Local LLM server (`https://ollama.home`)
- **[Firefly III](./services/firefly/README.md)** - Personal finance manager (`https://firefly.home`)
- **[AdGuard Home](./services/adguard/README.md)** - DNS server & ad blocker (`https://adguard.home`)

> [How to add a service](./docs/services.md)

Infrastructure components:
- **Portainer** - Docker management UI (`https://portainer.home`)
- **Nginx** - Reverse proxy and SSL termination
- **Cloudflare Tunnel** - Secure external access without port forwarding
- **Netdata** - Real-time system monitoring (`https://netdata.home`)
- **Backrest** - Web UI for restic backups (`https://backrest.home`)
- **Homepage** - Application dashboard (`https://homepage.home`)

## 📚 Documentation

[Read the docs here](./docs/README.md).