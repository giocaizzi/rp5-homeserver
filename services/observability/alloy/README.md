# Grafana Alloy Configuration

Centralized OpenTelemetry collector for logs, traces, and metrics.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              ALLOY PIPELINES                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐                    │
│  │   Docker    │     │    OTLP     │     │  Prometheus │                    │
│  │   Logs      │     │  Receiver   │     │   Scrape    │                    │
│  │             │     │             │     │  (modules)  │                    │
│  └──────┬──────┘     └──────┬──────┘     └──────┬──────┘                    │
│         │                   │                   │                            │
│         ▼                   ▼                   ▼                            │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐                    │
│  │  Relabel    │     │   Batch     │     │  Relabel    │                    │
│  │  + Process  │     │ + Attributes│     │  (module)   │                    │
│  └──────┬──────┘     └──────┬──────┘     └──────┬──────┘                    │
│         │                   │                   │                            │
│         │            ┌──────┴──────┐            │                            │
│         │            ▼      ▼      ▼            │                            │
│         │         Logs  Metrics Traces          │                            │
│         │            │      │      │            │                            │
│         ▼            ▼      ▼      ▼            ▼                            │
│      ┌──────┐     ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐                       │
│      │ Loki │     │ Loki │ │Prom  │ │Tempo │ │Prom  │                       │
│      │Write │     │Export│ │Export│ │OTLP  │ │Write │                       │
│      └──────┘     └──────┘ └──────┘ └──────┘ └──────┘                       │
│                                                                              │
│  ═══════════════════════════════════════════════════════════════════════    │
│                           outputs.alloy                                      │
│  ═══════════════════════════════════════════════════════════════════════    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Data Pipelines

| Pipeline | Source Label | Description |
|----------|--------------|-------------|
| Docker | `source=docker` | Container log scraping via Docker socket |
| OTEL | `source=otel` | Apps sending OTLP traces/metrics/logs |
| Scrape | `source=scrape` | Prometheus metric scraping |

## Label Schema

Labels are normalized to underscore format for Prometheus/Loki compatibility while maintaining alignment with OTEL semantic conventions.

### Indexed Labels (Low Cardinality)

Used for filtering in Loki/Prometheus queries. All pipelines output these consistently.

Label names follow OTEL semantic convention conversion: dots become underscores.

| Storage Label | OTEL Semconv | Docker Label | Default | Description |
|---------------|--------------|--------------|---------|-------------|
| `service_name` | `service.name` | `com.giocaizzi.service` | `unknown_service` | Logical service name |
| `service_namespace` | `service.namespace` | `com.giocaizzi.namespace` | `external` | Stack/project grouping |
| `deployment_environment_name` | `deployment.environment.name` | `com.giocaizzi.env` | `production` | Environment (prod/staging/dev) |
| `technology` | (custom) | `com.giocaizzi.technology` | — | Implementation technology (postgres, redis, nginx, etc.) |
| `tier` | (custom) | `com.giocaizzi.tier` | `core` | core/extra |
| `component` | (custom) | `com.giocaizzi.component` | — | app/data/worker/gateway |
| `source` | (custom) | (auto) | — | docker/otel/scrape |
| `level` | (auto/extracted) | (extracted) | `info` | Log severity (logs only) |

### Metadata Labels (High Cardinality)

Stored as structured metadata in Loki. Not indexed, but searchable.

| Storage Label | OTEL Semconv | Docker Label | Description |
|---------------|--------------|--------------|-------------|
| `service_instance_id` | `service.instance.id` | (container ID) | Unique instance identifier |
| `service_version` | `service.version` | `com.giocaizzi.version` | Service version |
| `host_name` | `host.name` | (hostname) | Container/host name |
| `role` | (custom) | `com.giocaizzi.role` | Specific function (backend, database, proxy, etc.) |

### Cardinality Strategy

**Why split labels?**
- Loki indexes labels for fast filtering. High-cardinality labels (like instance IDs) explode index size.
- Low-cardinality indexed labels enable efficient queries: `{service_namespace="firefly", component="data"}`
- High-cardinality data stored as structured metadata, searchable but not indexed.

**Query examples:**
```logql
# All logs from firefly stack
{service_namespace="firefly"}

# Database component logs with errors
{service_namespace="firefly", component="data", level="error"}

# All PostgreSQL databases across stacks
{technology="postgres"}

# Filter by environment
{deployment_environment_name="production"}

# Filter by instance (uses structured metadata)
{service_namespace="firefly"} | service_instance_id="abc123def456"
```

### Tier Values

| Value | Description |
|-------|-------------|
| `core` | Essential services for stack functionality |
| `extra` | Optional/auxiliary services |

### Component Values

| Value | Description |
|-------|-------------|
| `app` | Application servers, APIs, web UIs, backends |
| `data` | Databases, caches, object storage (postgres, redis, minio) |
| `worker` | Background processors, schedulers |
| `gateway` | Reverse proxies, load balancers, tunnels, DNS |

### Role Values (Free-form)

Specific function within the component. Examples:
- `backend`, `frontend`, `web`, `api`
- `database`, `analytics`
- `proxy`, `tunnel`
- `metrics`, `logs`, `traces`, `collector`
- `scheduler`, `importer`, `processor`
- `dns`, `dashboard`, `management`

### Technology Values

Implementation technology of the service. Used to identify all services using the same tech stack.

| Category | Values |
|----------|--------|
| Databases | `postgres`, `mariadb`, `mysql`, `clickhouse`, `sqlite` |
| Caches | `redis`, `valkey`, `memcached` |
| Web/Proxy | `nginx`, `caddy`, `traefik` |
| Observability | `grafana`, `prometheus`, `loki`, `tempo`, `alloy`, `netdata` |
| Applications | `firefly`, `n8n`, `langfuse`, `portainer`, `homepage`, `ntfy`, `ollama`, `adguard` |
| Utilities | `cloudflared`, `backrest` |

## OTEL Attribute Handling

### Incoming OTLP Data

Apps sending OTLP telemetry should use standard OTEL semantic conventions:
- `service.name`, `service.namespace`, `service.version`, `service.instance.id`
- `deployment.environment.name`
- `host.name`

The attributes processor:
1. Sets defaults for missing required attributes
2. Sets `loki.resource.labels` hint to control which attributes become Loki labels
3. Exporters auto-convert dots to underscores (e.g., `deployment.environment.name` → `deployment_environment_name`)

### Docker Container Discovery

Docker labels are mapped via relabeling rules:
1. Fallback chain: custom labels > swarm labels > compose labels > container metadata
2. Defaults applied for required labels
3. Same underscore naming as OTEL pipeline

## File Structure

| File | Purpose |
|------|---------|
| `modules.alloy` | Reusable custom components (`scrape_with_labels`, `scrape_observability`) |
| `outputs.alloy` | Loki + Prometheus remote write endpoints |
| `otel-receivers.alloy` | OTLP HTTP/gRPC receivers |
| `otel-processors.alloy` | Batch + transform processors (OTEL → underscore labels) |
| `otel-exporters.alloy` | Exporters to Loki, Prometheus, Tempo |
| `docker-logs.alloy` | Docker discovery, relabeling, log processing |
| `prometheus-scrape.alloy` | Prometheus metric scraping using custom components |

## Custom Components

Defined in `modules.alloy` using Alloy's `declare` block for code reuse.

### `scrape_with_labels`

Generic scraper with OTEL-aligned labels. Accepts service metadata and forwards to `prometheus.remote_write.default`.

```alloy
scrape_with_labels "service_name" {
  address           = "host:port"
  service_namespace = "stack_name"
  service_name      = "service"
  tier              = "core"       // optional, default: "core"
  component         = "data"       // optional, default: "data"
  role              = "database"
  technology        = "postgres"
  scrape_interval   = "30s"        // optional, default: "30s"
  scrape_timeout    = "10s"        // optional, default: "10s"
}
```

### `scrape_observability`

Specialized scraper for observability stack services. Pre-sets `service_namespace=observability`, `tier=core`, `component=observability`.

```alloy
scrape_observability "service_name" {
  address         = "host:port"
  service_name    = "traces"     // traces, metrics, logs, collector
  technology      = "tempo"
  scrape_interval = "15s"        // optional, default: "15s"
}
```