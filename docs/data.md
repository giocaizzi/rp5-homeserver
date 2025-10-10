# Data & Logs Structure

Essential guide for data persistence and log management in RP5 home server.

## Infrastructure Data

```
/home/pi/rp5-homeserver/infra/
├── docker-compose.yml       # Infrastructure stack compose file
├── .env                     # Environment variables
├── nginx/
│   ├── nginx.conf           # Nginx configuration
│   └── ssl/
│       ├── cert.pem         # SSL certificate
│       └── key.pem          # SSL private key
├── logs/
│   └── nginx/               # Nginx access and error logs
└── data/                    # (Optional) Persistent data for infra services
    └── <service>/           # e.g. Portainer, Cloudflared
```

## Portainer Remote Repository Structure

When deploying via Portainer remote repository, data on the Rasperry Pi is stored in Portainer's stack directories:

```
/opt/portainer/compose/
├── n8n_<id>/
│   ├── data/n8n/          # Workflows, credentials, SQLite DB
│   └── logs/n8n/          # Application logs
└── ollama_<id>/
    ├── data/ollama/       # Models and configuration
    └── logs/ollama/       # Inference logs
```

**Note**: `<id>` is Portainer's stack identifier

## Volume Mapping

The Standard Pattern for all services: 
- `./data/<service>` → container data directory
- `./logs/<service>` → container log directory

```yaml
volumes:
  - ${SERVICE_DATA_PATH:-./data/<service>}:/data
  - ${SERVICE_LOGS_PATH:-./logs/<service>}:/var/log
```

## Custom Paths

Paths can be customized, both for the infrastructure stack and Portainer stacks.

**Infrastructure Stack** (in `infra/.env`):

```bash
PORTAINER_DATA_PATH=""
```

**Environment Variables** (in Portainer):

```bash
# Override default paths if needed
N8N_DATA_PATH=/custom/path/n8n
N8N_LOGS_PATH=/custom/path/n8n/logs
```

## Log Configuration

**Rotation Settings** (all services):
```yaml
logging:
  driver: "json-file"
  options:
    max-size: "10m"    # Ollama: 50m for AI operations
    max-file: "3"
```

**Access Logs**:
- **Portainer UI**: Container logs viewer
- **CLI**: `docker logs <container>`
- **Host**: Stack directory + `/logs/<service>/`


## Permissions

**Portainer User**: Containers run as specified PUID/PGID
```bash
PUID=1000  # Pi user ID
PGID=1000  # Pi group ID
```

**Host Access**: Data owned by Docker daemon, accessible via Portainer


**CLI Access**:
```bash
# Check Portainer volume usage
docker system df
du -sh /home/pi/rp5-homeserver/**/data
du -sh /opt/portainer/compose/**/data
```