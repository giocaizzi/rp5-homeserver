# RP5 Home Server

Raspberry Pi 5 Docker-based home server.

## Quick Start

1. Deploy the [infrastructure stack](infra/README.md) with [Portainer](./setup.md).
2. Then access Portainer at `https://portainer.local` to deploy desired services.

## Services

- **[N8N](./services/n8n/README.md)** - Workflow automation (`https://n8n.local`)
- **[Ollama](./services/ollama/README.md)** - Local LLM server (`https://ollama.local`)
- **[Firefly III](./services/firefly/README.md)** - Personal finance manager (`https://firefly.local`)

> [How to add a service](./docs/services.md)


## Documentation

[Read the docs here](./docs/README.md).