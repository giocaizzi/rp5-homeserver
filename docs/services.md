# Adding New Services

Guidelines for adding service stacks that comply with RP5 architecture.

## Available Services

Current services deployed:

- **[Firefly III](../services/firefly/)** - Personal finance manager (`https://firefly.home`)
- **[N8N](../services/n8n/)** - Workflow automation (`https://n8n.home`) 
- **[Ollama](../services/ollama/)** - Local AI models (`https://ollama.home`)
- **[AdGuard Home](../services/adguard/)** - DNS server & ad blocker (`https://adguard.home`)

## Required Structure

```
services/new-service/
├── docker-compose.yml
├── .env.example  
└── README.md
```

## Docker Swarm Requirements

### Network Architecture
Services must connect to **both** networks for proper nginx routing in Docker Swarm:

```yaml
networks:
  # Private service network
  service_network:
    driver: overlay
    name: rp5_<service>
  
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
name: <service>

networks:
  service_network:
    driver: overlay
    name: rp5_<service>
  public_network:
    external: true
    name: rp5_public

services:
  service:
    image: <service>:latest
    hostname: <service>
    expose: ["<port>"]  # No ports: section
    volumes:
      - service_data:/data
      - service_logs:/var/log
    networks: 
      - service_network
      - public_network     # Required for nginx access
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:<port>"]
      start_period: 60s  # Pi startup time
    security_opt: [no-new-privileges:true]
    user: "1000:1000"
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      restart_policy:
        condition: any
        delay: 5s
        max_attempts: 3
        window: 120s
    logging:
      driver: "json-file"
      options: {max-size: "10m", max-file: "3"}

volumes:
  service_data:
    driver: local
  service_logs:
    driver: local
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
    server_name <service>.home;
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
- **Health**: 60s+ start period for Pi hardware

## Deployment Methods

### GitOps (Recommended)
Automated deployment with webhook integration:

1. **Deploy via Portainer GitOps:**
   - Access `https://portainer.home`
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
2. **Docker Swarm deployment:** `docker stack deploy -c docker-compose.yml <stack-name>` for production

See [Setup Guide](./setup.md#2-deploy-service-stacks) for detailed instructions.

## Documentation

Brief README template:
```markdown
# Service Name
Purpose and access via `https://service.home`

## Configuration  
Key settings and `.env.example` variables

## Deployment
Requires [infrastructure](../../infra) running first
```