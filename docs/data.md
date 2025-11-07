# Data & Volume Management

Essential guide for data persistence and volume management in RP5 home server with Docker Swarm.

## Volume Strategy

**Named Volumes for Persistent Data**: All services use Docker named volumes for persistent storage to ensure data integrity and easier management in the single-node swarm cluster.

**Bind Mounts for Configuration**: Only configuration files that may need external modification are mounted as bind mounts.

## Infrastructure Data

```
~/rp5-homeserver/infra/
├── docker-compose.yml       # Infrastructure swarm stack compose file
├── .env                     # Optional environment variables (Netdata token only)
├── VERSION                  # Infra version file (mounted as config)
├── nginx/
│   ├── nginx.conf           # Nginx configuration (bind mount)
│   └── snippets/            # Nginx configuration snippets
├── secrets/                 # Docker Swarm secrets (sensitive data)
│   ├── ssl_cert.pem         # SSL certificate
│   ├── ssl_key.pem          # SSL private key
│   ├── cloudflared_token.txt
│   ├── *_password.txt       # Service passwords
│   └── *.json               # API keys and service accounts
└── homepage/                # Homepage configuration (bind mount)
    ├── services.yaml
    ├── widgets.yaml
    └── ...
```

**Named Volumes (Swarm):**
- `infra_portainer_data` - Portainer application data and configuration
- `infra_netdata_cache` - Netdata performance metrics cache and time-series data
- `infra_netdata_config` - Netdata custom configuration and alerts
- `infra_netdata_lib` - Netdata runtime libraries and registry data


## Service Data

### N8N Stack
**Named Volumes:**
- `n8n_postgres_data` - PostgreSQL database for workflow data
- `n8n_n8n_data` - N8N additional data and configuration

### Ollama Stack
**Bind Mounts:**
- `./ollama-entrypoint.sh` - Custom entrypoint script

**Named Volumes:**
- `ollama_data` - AI models and configuration


## Volume Pattern

**Standard Named Volume Pattern** with `<stack>_<service>_<type>` naming for Docker Swarm:
```yaml
volumes:
  stack_service_data:
    driver: local
  stack_service_logs:
    driver: local
```

**Volume Mounting in Swarm**:
```yaml
services:
  service:
    volumes:
      - stack_service_data:/data
      - stack_service_logs:/var/log/service
      - ./config.conf:/etc/service/config.conf:ro  # Config only
    deploy:
      placement:
        constraints:
          - node.role == manager  # Ensures volume consistency
```

**Examples**:
- `infra_portainer_data`, `infra_netdata_cache`
- `n8n_postgres_data`, `n8n_n8n_data`
- `ollama_ollama_data`, `firefly_firefly_db`

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