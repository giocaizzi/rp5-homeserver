# Networking

Network topology, DNS resolution, and routing for single-node Docker Swarm.

## Network Layers

```mermaid
flowchart LR
    subgraph L1["Host Ports"]
        nginx[":80/:443"]
        dns[":53"]
    end

    subgraph L2["Overlay Networks"]
        public["rp5_public"]
        infra["rp5_infra"]
        stacks["rp5_<stack>"]
    end

    subgraph L3["Services"]
        apps["Applications"]
        dbs["Databases"]
    end

    Internet --> nginx
    LAN --> dns
    nginx --> public
    public --> apps
    infra --> apps
    stacks --> dbs
```

## Port Exposure Strategy

| Type | Directive | Scope | Use Case |
|------|-----------|-------|----------|
| Host | `ports:` | Internet/LAN | nginx (80/443), AdGuard DNS (53) |
| Overlay | `expose:` | Swarm internal | All other services |

**Rule**: Only nginx and AdGuard bind host ports. All other services use `expose` for overlay network access.

## Networks

| Network | Type | Purpose |
|---------|------|---------|
| `rp5_public` | External overlay | nginx → proxied services |
| `rp5_infra` | External overlay | Infrastructure services |
| `rp5_<stack>` | Stack overlay | Private per-stack communication |

Services join `rp5_public` only if nginx-proxied. Databases stay on private stack networks.

## Nginx Routing

nginx reverse-proxies all `.home` domains to internal services via overlay DNS.

| Domain | Service | Port |
|--------|---------|------|
| `portainer.home` | `infra_portainer` | 9000 |
| `netdata.home` | `infra_netdata` | 19999 |
| `backrest.home` | `infra_backrest` | 9898 |
| `homepage.home` | `infra_homepage` | 3000 |
| `n8n.home` | `n8n_n8n` | 5678 |
| `firefly.home` | `firefly_firefly` | 8080 |
| `firefly-importer.home` | `firefly_importer` | 8080 |
| `firefly-pico.home` | `firefly_pico` | 80 |
| `adguard.home` | `adguard_adguard` | 3000 |
| `ollama.home` | `ollama_ollama` | 11434 |
| `grafana.home` | `observability_grafana` | 3000 |
| `langfuse.home` | `langfuse_langfuse` | 3000 |
| `ntfy.home` | `ntfy_ntfy` | 80 |

**DNS Format**: `<stack>_<service>` (Swarm cross-stack resolution).

## DNS Resolution

Configure clients to resolve `.home` domains to the Pi's IP address.

### AdGuard DNS Rewrites (Recommended)

1. Access `https://adguard.home`
2. **Filters** → **DNS rewrites** → **Add DNS rewrite**
3. Add wildcard:
   - **Domain**: `*.home`
   - **IP Address**: `192.168.1.100` (Pi's IP)

This resolves all `.home` domains to the Pi. nginx routes to individual services.

### Client Configuration

**Network-wide** (recommended): Set Pi's IP as primary DNS in router DHCP settings.

**Per-device**: Edit `/etc/hosts` (Linux/macOS) or `C:\Windows\System32\drivers\etc\hosts`:
```
192.168.1.100 portainer.home netdata.home backrest.home homepage.home
192.168.1.100 firefly.home n8n.home grafana.home langfuse.home ntfy.home
```

### Static IP for Pi

Ensure Pi has static IP to avoid DNS resolution issues:

**Option 1**: DHCP reservation in router (recommended)  
**Option 2**: Static config in `/etc/dhcpcd.conf`:
```bash
interface eth0
static ip_address=192.168.1.100/24
static routers=192.168.1.1
static domain_name_servers=1.1.1.1 8.8.8.8
```

## Service Configuration

```yaml
# Nginx-proxied service
networks:
  - <stack>_network      # Private
  - public_network       # nginx access

# Database (internal only)
networks:
  - <stack>_network      # Private only
```

## Verification

```bash
# Check DNS resolution
nslookup portainer.home

# Check service ports
docker ps --format 'table {{.Names}}\t{{.Ports}}'

# Test connectivity from nginx
docker exec $(docker ps -q -f name=infra_nginx) nc -zv n8n_n8n 5678

# DNS resolution inside Swarm
docker exec $(docker ps -q -f name=infra_nginx) nslookup firefly_firefly
```
