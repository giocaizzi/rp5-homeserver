# RP5 Home Server

Raspberry Pi 5 Docker-based home server with Portainer stack management.

## Quick Start

Deploy the [infrastructure stack](../infra) first.

```bash
cd infra
cp .env.example .env
# Edit .env to add CLOUDFLARED_TOKEN
# Generate SSL certs
docker compose up -d
```

Then access Portainer at `https://portainer.local` to deploy services.

## Services

- **[N8N](./services/n8n/README.md)** - Workflow automation (`https://n8n.local`)
- **[Ollama](./services/ollama/README.md)** - Local LLM server (`https://ollama.local`)

## Documentation

[Read the docs here](./docs/README.md).