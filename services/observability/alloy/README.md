# Grafana Alloy Configuration

Centralized OpenTelemetry collector for logs, traces, and metrics.

## Architecture

```
alloy/
├── config.alloy           # Entry point - imports, shared discovery, outputs
├── modules/
│   └── labels.alloy       # Reusable label extraction (declare blocks)
└── pipelines/
    ├── otel.alloy         # OTLP receivers → processors → exporters
    ├── logs.alloy         # Docker log collection → Loki
    └── metrics.alloy      # Prometheus scraping → remote_write
```

### Data Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              ALLOY PIPELINES                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  pipelines/otel.alloy        pipelines/logs.alloy    pipelines/metrics.alloy│
│  ┌─────────────────┐        ┌─────────────────┐     ┌─────────────────┐     │
│  │  OTLP Receiver  │        │  Docker Logs    │     │  Prometheus     │     │
│  │  HTTP/gRPC      │        │  via Socket     │     │  Scrape         │     │
│  └────────┬────────┘        └────────┬────────┘     └────────┬────────┘     │
│           │                          │                       │              │
│           ▼                          ▼                       ▼              │
│  ┌─────────────────┐        ┌─────────────────┐     ┌─────────────────┐     │
│  │  Batch + Attrs  │        │  modules/labels │     │  modules/labels │     │
│  │  Processors     │        │  + Processing   │     │  + Relabel      │     │
│  └────────┬────────┘        └────────┬────────┘     └────────┬────────┘     │
│           │                          │                       │              │
│     ┌─────┼─────┐                    │                       │              │
│     ▼     ▼     ▼                    ▼                       ▼              │
│   Prom  Loki  Tempo               Loki                    Prom             │
│                                                                              │
│  ═══════════════════════════════════════════════════════════════════════    │
│                   config.alloy (outputs + shared discovery)                  │
│  ═══════════════════════════════════════════════════════════════════════    │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Data Pipelines

| Pipeline | Source Label | Description |
|----------|--------------|-------------|
| OTEL | `source=otel` | Apps sending OTLP traces/metrics/logs |
| Docker | `source=docker` | Container log scraping via Docker socket |
| Scrape | `source=scrape` | Prometheus metric scraping |

## Modular Design

### config.alloy (Entry Point)

- Imports modules and pipelines via `import.file`
- Shared `discovery.docker` instance (reduces Docker API calls)
- Module instantiation with shared discovery
- Output endpoints (`prometheus.remote_write`, `loki.write`)

### modules/labels.alloy (Reusable Components)

Contains `declare` blocks for consistent label extraction:

| Module | Purpose |
|--------|---------|
| `docker_labels` | Extract OTEL-aligned labels from Docker metadata |
| `exporter_targets` | Filter and prepare exporter targets for scraping |

### pipelines/ (Data Pipelines)

| File | Data Flow |
|------|-----------|
| `otel.alloy` | OTLP receivers → batch → attributes → backends |
| `logs.alloy` | Docker discovery → log collection → processing → Loki |
| `metrics.alloy` | Static + dynamic targets → scrape → Prometheus |

## Label Schema

Labels are normalized to underscore format for Prometheus/Loki compatibility while maintaining alignment with OTEL semantic conventions.

### Indexed Labels (Low Cardinality)

| Storage Label | OTEL Semconv | Docker Label | Default | Description |
|---------------|--------------|--------------|---------|-------------|
| `service_name` | `service.name` | `com.giocaizzi.service` | container name | Logical service name |
| `service_namespace` | `service.namespace` | `com.giocaizzi.namespace` | `external` | Stack/project grouping |
| `deployment_environment_name` | `deployment.environment.name` | `com.giocaizzi.env` | `production` | Environment |
| `technology` | (custom) | `com.giocaizzi.technology` | — | Implementation technology |
| `tier` | (custom) | `com.giocaizzi.tier` | `core` | core/extra |
| `component` | (custom) | `com.giocaizzi.component` | `app` | app/data/worker/gateway |
| `source` | (custom) | (auto) | — | docker/otel/scrape |
| `level` | (auto/extracted) | (extracted) | — | Log severity (logs only) |

### Metadata Labels (High Cardinality)

Stored as structured metadata in Loki. Not indexed, but searchable.

| Storage Label | OTEL Semconv | Docker Label |
|---------------|--------------|--------------|
| `service_instance_id` | `service.instance.id` | container ID |
| `service_version` | `service.version` | `com.giocaizzi.version` |
| `host_name` | `host.name` | hostname |

### Label Extraction Fallback Chain

The `docker_labels` module applies fallbacks:

```
service_namespace: custom label > swarm stack > compose project > "external"
service_name:      custom label > swarm service > compose service > container name
```

### Query Examples

```logql
# All logs from firefly stack
{service_namespace="firefly"}

# Database component logs with errors
{service_namespace="firefly", component="data", level="error"}

# All PostgreSQL databases across stacks
{technology="postgres"}

# Filter by instance (uses structured metadata)
{service_namespace="firefly"} | service_instance_id="abc123def456"
```

## Metrics Scraping Strategy

### Static Targets (observability stack)

Observability components use static targets in `metrics.alloy`:
- Alloy (127.0.0.1:12345)
- Prometheus (observability-metrics-store:9090)
- Loki (observability-log-store:3100)
- Tempo (observability-trace-store:3200)

### Dynamic Discovery (service exporters)

Service exporters use Docker discovery via `exporter_targets` module:

| Technology | Port | Normalized To |
|------------|------|---------------|
| postgres-exporter | 9187 | `postgres` |
| mysqld-exporter | 9104 | `mariadb` |
| redis-exporter | 9121 | `redis` |
| clickhouse | 9363 | `clickhouse` |

Benefits:
- **No scrape errors** when services aren't deployed
- **Automatic discovery** - new exporters scraped when deployed
- **Consistent labels** via shared module

## OTEL Integration

### Endpoints

| Protocol | Port | Description |
|----------|------|-------------|
| OTLP gRPC | 4317 | Binary protocol |
| OTLP HTTP | 4318 | JSON/Protobuf over HTTP |

### Incoming Data Requirements

Apps sending OTLP should use standard OTEL semantic conventions:
- `service.name`, `service.namespace`, `service.version`
- `deployment.environment.name`

The attributes processor adds defaults for missing required attributes.

### Example App Configuration

```yaml
environment:
  - OTEL_SERVICE_NAME=my-service
  - OTEL_RESOURCE_ATTRIBUTES=deployment.environment.name=production,service.namespace=mystack
  - OTEL_EXPORTER_OTLP_ENDPOINT=http://observability-collector:4318
```
