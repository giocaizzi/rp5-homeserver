# Adding New Services

Guidelines for adding service stacks that comply with RP5 architecture.

## Available Services

Current services deployed:

- **[Firefly III](../services/firefly/)** - Personal finance manager (`https://firefly.local`)
- **[N8N](../services/n8n/)** - Workflow automation (`https://n8n.local`) 
- **[Ollama](../services/ollama/)** - Local AI models (`https://ollama.local`)
- **[AdGuard Home](../services/adguard/)** - DNS server & ad blocker (`https://adguard.local`)

## Required Structure

```
services/new-service/
├── docker-compose.yml
├── .env.example  
└── README.md
```

## Docker Compose Requirements

### Network Architecture
Services must connect to **both** networks for proper nginx routing:

```yaml
networks:
  # Private service network
  service_network:
    driver: bridge
    name: rp5_<service>
    internal: false
  
  # Shared public network (created by infrastructure)
  public_network:
    external: true
    name: rp5_public

services:
  service:
    networks:
      - service_network    # Internal service communication
      - public_network     # Nginx proxy access
```

### Complete Service Template

```yaml
networks:
  service_network:
    name: rp5_<service>
  public_network:
    external: true
    name: rp5_public

services:
  service:
    image: <service>:latest
    container_name: <service>
    restart: unless-stopped
    expose: ["<port>"]  # No ports: section
    volumes:
      - ./data/<service>:/data
      - ./logs/<service>:/var/log
    networks: 
      - service_network
      - public_network     # Required for nginx access
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:<port>"]
      start_period: 60s  # Pi startup time
    security_opt: [no-new-privileges:true]
    user: "1000:1000"
    deploy:
      resources:
        limits: {memory: 1G, cpus: "1.0"}
    logging:
      options: {max-size: "10m", max-file: "3"}
```

## Nginx Integration

Services automatically join the `rp5_public` network, making them accessible to nginx.

Add to `/infra/nginx/nginx.conf`:

### 1. Upstream Definition
```nginx
upstream <service> { 
  server <service>:<port>; 
}
```

### 2. Server Block
```nginx
server {
    listen 443 ssl http2;
    server_name <service>.local;
    ssl_certificate /etc/nginx/ssl/cert.pem;
    ssl_private_key /etc/nginx/ssl/key.pem;
    
    location / {
        proxy_pass http://<service>;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## Required Patterns

- **Network**: `rp5_<service>` isolated network
- **Access**: Only via nginx proxy (no direct ports)
- **Data**: `./data/<service>` and `./logs/<service>`
- **Security**: Non-root user, no-new-privileges
- **Resources**: Pi-appropriate limits (≤2GB RAM, ≤2 CPU)
- **Health**: 60s+ start period for Pi hardware

## Deployment Methods

### GitOps (Recommended)
Automated deployment with webhook integration:

1. **Deploy via Portainer GitOps:**
   - Access `https://portainer.local`
   - Stacks → Add stack → Git Repository
   - Configure repository and enable GitOps webhooks
   - See [GitOps Documentation](./gitops.md) for details

2. **Benefits:**
   - Automatic updates on git push
   - Version control and audit trail
   - Easy rollback capabilities
   - Centralized configuration

### Manual Deployment (Alternative)
For services requiring manual control:

1. **Portainer UI:** Stacks → Add stack → Upload/Web editor
2. **SSH deployment:** `docker compose up -d` in service directory

See [Setup Guide](./setup.md#2-deploy-service-stacks) for detailed instructions.

## Documentation

Brief README template:
```markdown
# Service Name
Purpose and access via `https://service.local`

## Configuration  
Key settings and `.env.example` variables

## Deployment
Requires [infrastructure](../../infra) running first
```