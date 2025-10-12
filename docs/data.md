# Data & Volume Management

Essential guide for data persistence and volume management in RP5 home server.

## Volume Strategy

**Named Volumes for Persistent Data**: All services use Docker named volumes for persistent storage to ensure data integrity and easier management.

**Bind Mounts for Configuration**: Only configuration files that may need external modification are mounted as bind mounts.

## Infrastructure Data

```
~/rp5-homeserver/infra/
├── docker-compose.yml       # Infrastructure stack compose file
├── .env                     # Environment variables
└── nginx/
    ├── nginx.conf           # Nginx configuration (bind mount)
    └── ssl/
        ├── cert.pem         # SSL certificate (bind mount)
        └── key.pem          # SSL private key (bind mount)
```

**Named Volumes:**
- `infra_nginx_logs` - Nginx access and error logs
- `infra_portainer_data` - Portainer application data

## Service Data

### N8N Stack
**Named Volumes:**
- `n8n_postgres_data` - PostgreSQL database
- `n8n_n8n_data` - N8N workflows, credentials, and settings
- `n8n_n8n_logs` - N8N application logs

### Ollama Stack
**Bind Mounts:**
- `./ollama-entrypoint.sh` - Custom entrypoint script

**Named Volumes:**
- `ollama_ollama_data` - AI models and configuration
- `ollama_ollama_logs` - Inference and application logs

## Volume Pattern

**Standard Named Volume Pattern** with `<stack>_<service>_<type>` naming:
```yaml
volumes:
  stack_service_data:
    driver: local
  stack_service_logs:
    driver: local
```

**Volume Mounting**:
```yaml
services:
  service:
    volumes:
      - stack_service_data:/data
      - stack_service_logs:/var/log/service
      - ./config.conf:/etc/service/config.conf:ro  # Config only
```

**Examples**:
- `infra_nginx_logs`, `infra_portainer_data`
- `n8n_postgres_data`, `n8n_n8n_data`, `n8n_n8n_logs`  
- `ollama_ollama_data`, `ollama_ollama_logs`

## Volume Management

**List All Volumes**:
```bash
docker volume ls
```

**Inspect Volume Details**:
```bash
docker volume inspect <volume_name>
```

**Volume Location**: 
Docker manages volume storage automatically, typically under `/var/lib/docker/volumes/`

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
- **Volume Data**: `docker volume inspect <volume_name>`

## Permissions

**Volume Ownership**: Docker manages volume permissions automatically

**Container User**: Containers run as specified PUID/PGID when applicable
```bash
PUID=1000  # Pi user ID  
PGID=1000  # Pi group ID
```



**CLI Volume Usage Check**:
```bash
# Check Docker volume usage
docker system df -v
```