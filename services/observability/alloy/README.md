# Grafana Alloy Configuration

Centralized OpenTelemetry collector for logs, traces, and metrics.

## Data Pipelines

| Pipeline | Source Label | Description |
|----------|--------------|-------------|
| OTEL | `source=otel` | Apps sending OTLP traces/metrics/logs |
| Docker | `source=docker` | Container log scraping |
| Scrape | `source=scrape` | Prometheus metric scraping |

## Label Schema (Docker ↔ OTEL)

| Docker Label | Alloy Label | OTEL Attribute |
|--------------|-------------|----------------|
| `com.giocaizzi.service` | `service_name` | `service.name` |
| `com.giocaizzi.version` | `version` | `service.version` |
| `com.giocaizzi.env` | `environment` | `deployment.environment` |
| `com.giocaizzi.tier` | `tier` | (custom) |
| `com.giocaizzi.component` | `component` | (custom) |
| `com.giocaizzi.role` | `role` | (custom) |
| `com.giocaizzi.namespace` | `namespace` | (custom) |
| `container_id` | `instance` | `service.instance.id` |
| `hostname` | `host` | `host.name` |
| (auto) | `source` | (custom: otel/docker/scrape) |

### Tier Values

| Value | Description |
|-------|-------------|
| `core` | Essential services for stack functionality |
| `extra` | Optional/auxiliary services |

### Component Values (standardized)

| Value | Description |
|-------|-------------|
| `app` | Application servers, APIs, web UIs, backends |
| `data` | Databases (postgres, mysql, mariadb, clickhouse) |
| `storage` | Object/file storage (minio, s3) |
| `cache` | Caching layers (redis, valkey) |
| `worker` | Background processors, schedulers |
| `gateway` | Reverse proxies, load balancers, tunnels |
| `network` | DNS, DHCP, networking services |
| `observability` | Monitoring, logging, tracing, metrics |

### Role Values (free-form)

Specific function within the component. Examples:
- `backend`, `frontend`, `web`, `api`
- `database`, `analytics`
- `proxy`, `tunnel`
- `metrics`, `logs`, `traces`, `collector`
- `scheduler`, `importer`, `processor`
- `dns`, `dashboard`, `management`

### Default Values

- `environment`: `production`

## File Structure

| File | Purpose |
|------|---------|
| `outputs.alloy` | Loki + Prometheus remote write endpoints |
| `otel-receivers.alloy` | OTLP HTTP/gRPC receivers |
| `otel-processors.alloy` | Batch + attributes processors |
| `otel-exporters.alloy` | Exporters to Loki, Prometheus, Tempo |
| `docker-logs.alloy` | Docker discovery, relabeling, log processing |
| `prometheus-scrape.alloy` | cAdvisor and Tempo scrape + relabeling |
| `langfuse.alloy` | Langfuse OTLP export (disabled by default) |

## Enabling Langfuse Export

1. Create secrets: `observability_langfuse_public_key`, `observability_langfuse_secret_key`
2. Uncomment secrets in `docker-compose.yml`
3. Uncomment all blocks in `langfuse.alloy`
4. Add `otelcol.exporter.otlphttp.langfuse.input` to traces output in `otel-processors.alloy`
