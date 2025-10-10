# Base Infrastructure

Rasperry Pi 5 Home Server base infrastructure.


- [Portainer](https://www.portainer.io/) - Docker management UI
- [Cloudflared](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/) - Cloudflare Tunnel client to expose Portainer securely to the internet


## Usage

```bash
CLOUDFLARED_TOKEN="" docker-compose up -d
```