# RP5 Home Server

Raspberry Pi 5 Docker-based home server.

## 🚀 Quick Start

1. Deploy the [infrastructure stack](infra/README.md) with [Portainer](./setup.md).
2. Then access Portainer at `https://portainer.local` to deploy desired services.

## 🧩 Services

Applications available for deployment:

- **[N8N](./services/n8n/README.md)** - Workflow automation (`https://n8n.local`)
- **[Ollama](./services/ollama/README.md)** - Local LLM server (`https://ollama.local`)
- **[Firefly III](./services/firefly/README.md)** - Personal finance manager (`https://firefly.local`)

> [How to add a service](./docs/services.md)

Infrastructure components:
- **Portainer** - Docker management UI (`https://portainer.local`)
- **Nginx** - Reverse proxy and SSL termination
- **Cloudflare Tunnel** - Secure external access without port forwarding
- **Netdata** - Real-time system monitoring (`https://netdata.local`)
- **Backrest** - Web UI for restic backups (`https://backrest.local`)
- **Homepage** - Application dashboard (`https://homepage.local`)

## 📚 Documentation

[Read the docs here](./docs/README.md).