# rp5-homeserver

Rasperry Pi 5 Home Server setup based on Docker.

## Infrastructure 

### Docker compose base stack

Base infrastructure Docker compose stack [infra](./infra)

- [Portainer]() - Docker management UI
- [Cloudflared]() - Cloudflare Tunnel client to expose Portainer securely to the internet

### Host base setup

- [Netdata](./host/netdata) - Real-time performance monitoring with access to system metrics and alerts

## Docker Services

- [n8n]() - Workflow automation tool
- [ollama]() - Local LLM server
