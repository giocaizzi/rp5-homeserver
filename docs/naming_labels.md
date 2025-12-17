# 🏷️ Naming & Labeling Standards

Standards for Docker Compose service naming, hostnames, and container labels. Used for service identification, observability, and network resolution.

---

## Naming Conventions

### Stack Name

The **stack name** is the top-level identifier (folder name in `services/` or `infra`).

| Stack | Description |
|-------|-------------|
| `infra` | Core infrastructure |
| `n8n` | N8N automation |
| `firefly` | Firefly III finance |
| `langfuse` | LLM observability |
| `observability` | Monitoring stack |
| `adguard` | DNS filtering |
| `ntfy` | Push notifications |
| `ollama` | LLM inference |

### Service Name (Compose Key)

The Docker Compose service key under `services:`. Use generic, functional names—never technology names.

```yaml
services:
  db:           # ✅ generic
  app:          # ✅ primary application
  cache:        # ✅ generic (not redis)
  db-exporter:  # ✅ generic exporter
  storage:      # ✅ generic (not minio)
```

| Pattern | Examples |
|---------|----------|
| Primary app | `app` |
| Database | `db`, `pico-db` (scoped) |
| Cache | `cache` |
| Storage | `storage`, `analytics` |
| Workers | `worker`, `scheduler`, `importer` |
| Exporters | `db-exporter`, `cache-exporter`, `pico-db-exporter` (scoped) |
| Telemetry | `metrics-store`, `log-store`, `trace-store`, `collector` |
| Infrastructure | `proxy`, `dns`, `tunnel`, `monitoring`, `backup`, `management`, `dashboard` |

### Hostname

**Pattern:** `<stack>-<service>`

The hostname enables DNS resolution within Docker networks and becomes `host.name` in telemetry.

```yaml
services:
  db:
    hostname: n8n-db           # stack=n8n, service=db
  
  db-exporter:
    hostname: n8n-db-exporter
```

| Stack | Service | Hostname |
|-------|---------|----------|
| `infra` | `proxy` | `infra-proxy` |
| `n8n` | `db` | `n8n-db` |
| `n8n` | `app` | `n8n-app` |
| `langfuse` | `analytics` | `langfuse-analytics` |
| `observability` | `dashboard` | `observability-dashboard` |

---

## Docker Labels

All containers must include these labels for identification and observability.

### Required Labels (6)

| Label | Description | Derives From |
|-------|-------------|--------------|
| `com.giocaizzi.namespace` | Stack name | Folder/stack name |
| `com.giocaizzi.env` | Environment | Always `production` |
| `com.giocaizzi.service` | Service identifier | Compose service key (must match) |
| `com.giocaizzi.component` | Architectural layer | See values below |
| `com.giocaizzi.tier` | Criticality | `core` or `extra` |
| `com.giocaizzi.technology` | Tool/image name | Base image name |

### Label Values

#### `component` (4 values)

| Value | Description | Examples |
|-------|-------------|----------|
| `app` | Main application (UI, API) | n8n, grafana, portainer, homepage |
| `data` | Data storage | postgres, redis, minio, clickhouse, prometheus, loki, tempo |
| `worker` | Background processor | exporters, collectors, schedulers, importers |
| `gateway` | Network entry point | nginx, adguard, cloudflared |

#### `tier` (2 values)

| Value | Description |
|-------|-------------|
| `core` | Essential for stack functionality |
| `extra` | Optional, supporting (exporters, agents) |

#### `technology`

Use the tool/image name: `postgres`, `redis`, `nginx`, `grafana`, `prometheus`, `loki`, `tempo`, `alloy`, `minio`, `clickhouse`, `mariadb`, `n8n`, `ntfy`, `adguard`, `cloudflared`, `netdata`, `backrest`, `portainer`, `homepage`, `ollama`, `langfuse`, `firefly`, `postgres-exporter`, `redis-exporter`, `mysqld-exporter`

---

## Complete Example

```yaml
x-labels-base: &labels-base
  com.giocaizzi.namespace: "mystack"
  com.giocaizzi.env: "production"

services:
  db:
    image: postgres:16-alpine
    hostname: mystack-db           # <stack>-<service>
    labels:
      <<: *labels-base
      com.giocaizzi.service: "db"         # matches compose key
      com.giocaizzi.component: "data"
      com.giocaizzi.tier: "core"
      com.giocaizzi.technology: "postgres"

  app:
    image: myapp:latest
    hostname: mystack-app
    labels:
      <<: *labels-base
      com.giocaizzi.service: "app"
      com.giocaizzi.component: "app"
      com.giocaizzi.tier: "core"
      com.giocaizzi.technology: "myapp"

  db-exporter:
    image: quay.io/prometheuscommunity/postgres-exporter:latest
    hostname: mystack-db-exporter
    labels:
      <<: *labels-base
      com.giocaizzi.service: "db-exporter"
      com.giocaizzi.component: "worker"
      com.giocaizzi.tier: "extra"
      com.giocaizzi.technology: "postgres-exporter"
```

---

## Naming Summary

| Element | Pattern | Example |
|---------|---------|---------|
| Stack | `<name>` | `n8n`, `infra` |
| Service (compose key) | `<function>` | `db`, `app`, `db-exporter` |
| Hostname | `<stack>-<service>` | `n8n-db`, `infra-proxy` |
| Network | `<stack>_network` | `n8n_network` |
| Volume | `<purpose>_data` | `postgres_data` |
| Secret | `<name>` | `postgres_password` |
| Config | `<name>_config` | `postgres_config` |

---

## Observability Integration

Labels are extracted by the telemetry collector and mapped to OpenTelemetry attributes:

| Docker Label | OTel Attribute | Used For |
|--------------|----------------|----------|
| `com.giocaizzi.namespace` | `service.namespace` | Service grouping |
| `com.giocaizzi.service` | `service.name` | Service identification |
| `com.giocaizzi.env` | `deployment.environment.name` | Environment filtering |
| `com.giocaizzi.technology` | `technology` | Technology filtering |
| `com.giocaizzi.tier` | `tier` | Criticality filtering |
| `com.giocaizzi.component` | `component` | Architecture filtering |

The hostname (`<stack>-<service>`) becomes the `host.name` attribute in telemetry data, enabling correlation between container logs/metrics and the service labels.