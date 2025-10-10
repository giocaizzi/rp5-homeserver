# Data & Logs Structure

Essential guide for data persistence and log management in RP5 home server.

## Portainer Remote Repository Structure

When deploying via Portainer remote repository, data on the Rasperry Pi is stored in Portainer's stack directories:

```
/opt/portainer/compose/
├── infrastructure_<id>/
│   ├── data/portainer/     # Portainer configuration
│   ├── logs/nginx/         # Nginx access/error logs
│   └── nginx/ssl/          # SSL certificates
├── n8n_<id>/
│   ├── data/n8n/          # Workflows, credentials, SQLite DB
│   └── logs/n8n/          # Application logs
└── ollama_<id>/
    ├── data/ollama/       # Models and configuration
    └── logs/ollama/       # Inference logs
```

**Note**: `<id>` is Portainer's stack identifier

## Volume Mapping

**Standard Pattern**: `./data/<service>` → container data directory
```yaml
volumes:
  - ${SERVICE_DATA_PATH:-./data/<service>}:/data
  - ${SERVICE_LOGS_PATH:-./logs/<service>}:/var/log
```

**Environment Variables** (in Portainer):
```bash
# Override default paths if needed
N8N_DATA_PATH=/custom/path/n8n
OLLAMA_DATA_PATH=/custom/path/ollama
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
du -sh /opt/portainer/compose/*/data
```