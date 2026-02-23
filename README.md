# RP5 Home Server

Raspberry Pi 5 Docker Swarm-based home server.

## 🚀 Quick Start

1. Deploy the [infrastructure stack](infra/README.md) with Docker Swarm
2. Access Portainer at `https://portainer.home` to deploy services

## 🧩 Services

| Service | URL | Description |
|---------|-----|-------------|
| **[N8N](./services/n8n/README.md)** | `https://n8n.home` | Workflow automation |
| **[Firefly III](./services/firefly/README.md)** | `https://firefly.home` | Personal finance |
| **[AdGuard Home](./services/adguard/README.md)** | `https://adguard.home` | DNS & ad blocking |
| **[Ollama](./services/ollama/README.md)** | `https://ollama.home` | Local LLM server |
| **[Langfuse](./services/langfuse/README.md)** | `https://langfuse.home` | LLM observability |
| **[Ntfy](./services/ntfy/README.md)** | `https://ntfy.home` | Push notifications |
| **[Observability](./services/observability/README.md)** | `https://grafana.home` | Grafana, Loki, Tempo, Prometheus |

**Infrastructure** (deployed with `infra/`):
- **Portainer** — Docker management (`https://portainer.home`)
- **Nginx** — Reverse proxy & SSL
- **Cloudflare Tunnel** — Secure external access
- **Netdata** — System monitoring (`https://netdata.home`)
- **Backrest** — Backup UI (`https://backrest.home`)
- **Homepage** — Dashboard (`https://homepage.home`)
- **Shepherd** — Auto-updates Swarm services every 24h

## 📚 Documentation

See [docs/](./docs/README.md) for architecture, networking, backup, and deployment guides.