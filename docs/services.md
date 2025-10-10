# Adding New Services

Guidelines for adding service stacks that comply with RP5 architecture.

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

## Process
1. Create `./services/<service>` with required files
1. Add service to nginx config
2. [Deploy service](./deployment.md) with Portainer or CLI
3. Add `<service>.local` to hosts file

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