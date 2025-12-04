# Monitoring & Observability

Observability stack using OTEL-compliant practices with Grafana, Loki, Tempo, and Prometheus.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     observability stack                         │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │   Grafana   │  │   Alloy     │  │ Prometheus  │             │
│  │ (Dashboard) │  │ (Collector) │  │  (Metrics)  │             │
│  └─────────────┘  └──────┬──────┘  └─────────────┘             │
│                          │                                      │
│         ┌────────────────┼────────────────┐                    │
│         │                │                │                     │
│  ┌──────▼──────┐  ┌──────▼──────┐  ┌──────▼──────┐             │
│  │    Loki     │  │    Tempo    │  │ Prometheus  │             │
│  │   (Logs)    │  │  (Traces)   │  │  (Metrics)  │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
└─────────────────────────────────────────────────────────────────┘
```

---

## Components

| Service | Hostname | Technology | Role | Port |
|---------|----------|------------|------|------|
| Grafana | `observability-grafana` | grafana | Dashboard & visualization | 3000 |
| Alloy | `observability-alloy` | alloy | Telemetry collector | 12345, 4317, 4318 |
| Prometheus | `observability-prometheus` | prometheus | Metrics storage | 9090 |
| Loki | `observability-loki` | loki | Log aggregation | 3100 |
| Tempo | `observability-tempo` | tempo | Distributed tracing | 3200, 4317, 4318 |

---

## Host Monitoring

### Netdata
Lightweight real-time monitoring running as a Docker container in the infra stack.

**Hostname:** `infra-netdata`

**Access:**
- Via nginx proxy: `https://netdata.home` (recommended)
- Direct access: `http://pi.local:19999` (fallback)
- Real-time system metrics and alerts
- No authentication required (internal network only)

---

## Telemetry Pipeline

### Grafana Alloy

Unified telemetry collector handling logs, metrics, and traces.

**Endpoints:**
- Health UI: `http://observability-alloy:12345`
- OTLP gRPC: `observability-alloy:4317`
- OTLP HTTP: `observability-alloy:4318`

**Pipelines:**

| Pipeline | Source | Destination | Labels |
|----------|--------|-------------|--------|
| Docker Logs | Docker socket | Loki | `service_namespace`, `service_name`, `technology`, `component`, `tier`, `level` |
| Prometheus Scrape | Internal services | Prometheus | `job`, `instance`, `service_name`, `technology` |
| OTLP Traces | Application SDKs | Tempo | OTEL semantic conventions |

### Label Schema

Labels extracted from Docker containers and forwarded to observability backends. Names follow OTEL semantic conventions (dots → underscores).

**Indexed Labels (Low Cardinality):**

| Label | Source | Description |
|-------|--------|-------------|
| `service_namespace` | `com.giocaizzi.namespace` | Stack name (e.g., `firefly`, `n8n`) |
| `service_name` | `com.giocaizzi.service` | Logical service name (e.g., `app`, `db`) |
| `deployment_environment_name` | `com.giocaizzi.env` | Environment (`production`, `staging`, `dev`) |
| `technology` | `com.giocaizzi.technology` | Implementation technology (e.g., `postgres`, `redis`) |
| `tier` | `com.giocaizzi.tier` | Service tier (`core`, `extra`) |
| `component` | `com.giocaizzi.component` | Component type (`app`, `data`, `worker`, `gateway`) |
| `source` | Auto-detected | Pipeline source (`docker`, `otel`, `scrape`) |
| `level` | Extracted | Log severity (`info`, `error`, etc.) |

**Metadata Labels (High Cardinality):**

| Label | Source | Description |
|-------|--------|-------------|
| `service_instance_id` | Container ID | Unique instance identifier |
| `service_version` | `com.giocaizzi.version` | Service version |
| `host_name` | Hostname | Container/host name |
| `role` | `com.giocaizzi.role` | Service role (`database`, `cache`, `proxy`, `backend`...) |

---

## Metrics Collection

### Prometheus Targets

Prometheus scrapes metrics from internal services via Alloy.

**Observability Stack:**

| Target | Endpoint | Metrics |
|--------|----------|---------|
| Prometheus | `observability-prometheus:9090/metrics` | Self-monitoring |
| Loki | `observability-loki:3100/metrics` | Log ingestion stats |
| Tempo | `observability-tempo:3200/metrics` | Trace ingestion stats |
| Alloy | `observability-alloy:12345/metrics` | Pipeline health |

**Database Exporters:**

| Target | Stack | Endpoint | Metrics |
|--------|-------|----------|---------|
| n8n-postgres-exporter | n8n | `:9187/metrics` | PostgreSQL stats |
| firefly-mysql-exporter | firefly | `:9104/metrics` | MariaDB stats |
| firefly-postgres-exporter | firefly | `:9187/metrics` | Pico PostgreSQL |
| langfuse-postgres-exporter | langfuse | `:9187/metrics` | Langfuse PostgreSQL |
| langfuse-redis-exporter | langfuse | `:9121/metrics` | Redis stats |
| langfuse-clickhouse | langfuse | `:9363/metrics` | ClickHouse stats |

Exporters use entrypoint scripts to inject credentials from Docker Swarm secrets.

---

## Log Aggregation

### Loki

Horizontally-scalable log aggregation with label-based indexing.

**Endpoint:** `http://observability-loki:3100`

**Log Sources:**
- Docker container logs (via Alloy `loki.source.docker`)
- All containers with `com.giocaizzi.namespace` label

**Query Examples:**
```logql
# All logs from firefly stack
{service_namespace="firefly"}

# Database logs across all stacks
{technology=~"postgres|mariadb"}

# Error logs from app components
{component="app", level="error"}

# Filter by instance (structured metadata)
{service_namespace="firefly"} | service_instance_id="abc123"
```

---

## Distributed Tracing

### Tempo

Distributed tracing backend for OTLP-compatible traces.

**Endpoints:**
- Query API: `http://observability-tempo:3200`
- OTLP gRPC: `observability-tempo:4317`
- OTLP HTTP: `observability-tempo:4318`

**Instrumented Services:**
- Langfuse (auto-instrumented)
- n8n (via OTEL SDK)
- Custom applications with OTEL SDK

---

## Grafana Dashboards

### Access
- URL: `https://grafana.home`
- Default credentials in Swarm secrets

### Dashboard Organization

Dashboards are organized in folders by purpose:

| Folder | Dashboards | Description |
|--------|------------|-------------|
| `infra` | docker-overview | Docker Swarm container resources |
| `observability` | health | Loki/Tempo/Prometheus/Alloy health |
| `giocaizzi-xyz` | app, ai | Personal website application |
| `shared` | postgresql, mariadb, redis, nginx | Technology-specific dashboards (multi-instance) |

### Dashboard Variables

Dashboards use variables for dynamic filtering:

| Variable | Purpose | Example Values |
|----------|---------|----------------|
| `$service_namespace` | Filter by stack | `n8n`, `firefly`, `langfuse` |
| `$service_name` | Filter by service | `db`, `cache`, `app` |
| `$datasource` | Select Prometheus/Loki instance | — |

Shared dashboards (PostgreSQL, Redis) use both variables for multi-instance support.

### Data Sources (Pre-configured)
| Name | Type | URL |
|------|------|-----|
| Prometheus | prometheus | `http://observability-prometheus:9090` |
| Loki | loki | `http://observability-loki:3100` |
| Tempo | tempo | `http://observability-tempo:3200` |

---

## Alerting

Alerting is handled via Grafana alerting rules, with notifications sent to ntfy.

**Alert Channels:**
- ntfy: `https://ntfy.home/alerts`

**Provisioned Alert Rules:**

| Group | Alerts |
|-------|--------|
| Database Alerts | PostgreSQL Down, PostgreSQL Low Cache Hit, MariaDB Down |
| Redis Alerts | Redis Down, Redis High Memory |
| Exporter Health | Metrics Exporter Down |
| Observability Stack | Loki Down, Tempo Down, Alloy Down |

Alert rules are provisioned via `grafana/provisioning/alerting/rules.yaml`.

---

## Troubleshooting

### Common Issues

**Logs not appearing in Loki:**
1. Check container has `com.giocaizzi.namespace` label
2. Verify Alloy can access Docker socket
3. Check Alloy logs: `docker service logs observability_alloy`

**Traces not appearing in Tempo:**
1. Verify OTLP endpoint configuration in application
2. Check Tempo is receiving data: `curl http://observability-tempo:3200/ready`
3. Check Alloy OTLP receiver: `curl http://observability-alloy:12345/metrics`

**High memory usage:**
- Reduce Loki retention period
- Adjust Prometheus scrape intervals
- Check Tempo trace sampling rate