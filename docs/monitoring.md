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

| Service | Hostname | Technology | Port |
|---------|----------|------------|------|
| Grafana | `observability-dashboard` | grafana | 3000 |
| Alloy | `observability-collector` | alloy | 12345, 4317, 4318 |
| Prometheus | `observability-metrics-store` | prometheus | 9090 |
| Loki | `observability-log-store` | loki | 3100 |
| Tempo | `observability-trace-store` | tempo | 3200, 4317, 4318 |

---

## Host Monitoring

### Netdata
Lightweight real-time monitoring running as a Docker container in the infra stack.

**Hostname:** `infra-monitoring`

**Access:**
- Via nginx proxy: `https://netdata.home` (recommended)
- Direct access: `http://pi.local:19999` (fallback)
- Real-time system metrics and alerts
- No authentication required (internal network only)

### Disk Hygiene

`/` (NVMe) holds `/var/lib/docker`. Without cleanup it grew ~1 GiB/day from old images left by CI and Shepherd redeploys (231 → 295 GiB, Aug–Oct 2026; manual cleanup on 15–16 Oct 2026 freed ~255 GiB, #454). Two pieces keep it flat:

| Piece | What it does |
|-------|--------------|
| `infra_janitor` | Every 24h (from its start): prunes stopped containers older than 24h and unused images older than 48h. Never touches volumes. Goes through `infra_docker-proxy`, whose allowlist permits only the two prune endpoints for it. |
| Netdata `root_disk_used` ([`health.d/disk_used.conf`](../infra/netdata/health.d/disk_used.conf)) | Used space on `/`: warning above 80 GiB, critical (ntfy) above 120 GiB. Normal is ~45 GiB. |

Images of stopped on-demand stacks are pruned after 48h and pulled again on the next deploy.

**If `root_disk_used` fires:** check the janitor ran (`docker service logs --since 48h infra_janitor` shows a daily `Total reclaimed space`), then find the growth (`docker system df -v`, `sudo du -xh --max-depth=2 /var/lib/docker | sort -h | tail`).

---

## Telemetry Pipeline

### Grafana Alloy

Unified telemetry collector handling logs, metrics, and traces.

**Endpoints:**
- Health UI: `http://observability-collector:12345`
- OTLP gRPC: `observability-collector:4317`
- OTLP HTTP: `observability-collector:4318`

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

---

## Metrics Collection

### Prometheus Targets

Prometheus scrapes metrics from internal services via Alloy.

**Observability Stack:**

| Target | Endpoint | Metrics |
|--------|----------|---------||
| Prometheus | `observability-metrics-store:9090/metrics` | Self-monitoring |
| Loki | `observability-log-store:3100/metrics` | Log ingestion stats |
| Tempo | `observability-trace-store:3200/metrics` | Trace ingestion stats |
| Alloy | `observability-collector:12345/metrics` | Pipeline health |

**Database Exporters:**

| Target | Stack | Endpoint | Metrics |
|--------|-------|----------|---------||
| n8n-db-exporter | n8n | `:9187/metrics` | PostgreSQL stats |
| firefly-db-exporter | firefly | `:9104/metrics` | MariaDB stats |
| langfuse-db-exporter | langfuse | `:9187/metrics` | Langfuse PostgreSQL |
| langfuse-cache-exporter | langfuse | `:9121/metrics` | Redis stats |
| langfuse-analytics | langfuse | `:9363/metrics` | ClickHouse stats |

Exporters use entrypoint scripts to inject credentials from Docker Swarm secrets.

---

## Log Aggregation

### Loki

Horizontally-scalable log aggregation with label-based indexing.

**Endpoint:** `http://observability-log-store:3100`

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
- Query API: `http://observability-trace-store:3200`
- OTLP gRPC: `observability-trace-store:4317`
- OTLP HTTP: `observability-trace-store:4318`

**Instrumented Services:**
- Langfuse (auto-instrumented)
- n8n (via OTEL SDK)
- Custom applications with OTEL SDK

**Restart log lines (#290):** shutdown is graceful (`stop_grace_period: 90s`, "Tempo stopped" in a few seconds). Expected on every restart, all benign upstream behaviour:
- `warn` `failed to replay block. removing.` (missing `meta.json`): the empty head block cut at shutdown, discarded on replay.
- Tempo logs three upstream races at ERROR; Alloy demotes them to `warn` (`alloy/pipelines/logs.alloy`), so they do not count as errors or trip Container Error Logs Burst: `error tailing WAL ... failed to find segment for index` (the metrics-generator wipes its WAL on start and its remote-write watcher starts before segment 0 exists, then recovers), `queue is stopped` (query-frontend stops before the querier worker), `failed listing tenant blocks: open <uuid>: no such file or directory` (poller walks `traces/` while the compactor deletes a block). `docker service logs` still shows them as `level=error`.

**Firefly cron token line (#328):** every call to `/api/v1/cron/<STATIC_CRON_TOKEN>` (the scheduler's daily 06:00 job) logs `production.ERROR: Recognized no users by access token "<prefix>..."`. Upstream `CronController` checks the static token first, then always looks it up as a per-user command-line token, logs the miss at ERROR, and runs the cron for all users anyway. The token is valid; check the `last_rt_job_<user>` / `last_ab_job_<user>` rows in Firefly's `configuration` table to confirm the jobs ran. Alloy demotes the line to `warn` (`alloy/pipelines/logs.alloy`).

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
| `Website` | app, ai | Website application (pick namespace/service in the dashboard variables) |
| `shared` | postgresql, mariadb, redis, nginx | Technology-specific dashboards (multi-instance) |
| `claude-code` | dashboard | Claude Code metrics in depth (Prometheus) |
| `Agents` | overview, ops | Every agent harness: cost, tokens, errors (Agent Overview); guard, skills, tools, subagents (Agent Ops) |

### Dashboard Variables

Dashboards use variables for dynamic filtering:

| Variable | Purpose | Example Values |
|----------|---------|----------------|
| `$service_namespace` | Filter by stack | `n8n`, `firefly`, `langfuse` |
| `$service_name` | Filter by service | `db`, `cache`, `app` |
| `$datasource` | Select Prometheus/Loki instance | — |

Shared dashboards (PostgreSQL, Redis) use both variables for multi-instance support.

### Agent cost

The Agents folder reads one request schema that `alloy/pipelines/otel.alloy` (`agent_usage`) builds from every harness: each model call is a Loki record with `agent_event="api_request"` and `model`, `session_id`, `input_tokens` (uncached), `output_tokens`, `cache_read_tokens` and `cost_usd` in structured metadata. `service_name` is the harness: `claude-code`, `codex`, `github-copilot` (Copilot CLI), `copilot-chat` (VS Code), `opencode`, `pi`.

| Harness | Sends | Cost from | Price basis |
|---------|-------|-----------|-------------|
| Claude Code | OTLP logs (`api_request`) | its own `cost_usd` | Anthropic API list price, computed by Claude Code |
| opencode, pi | the guard plugin's `api_request` | the harness's own cost | the harness's model catalogue |
| Codex | OTLP logs (`codex.sse_event` `response.completed`) | the Alloy price table | OpenAI API list price (Standard) |
| Copilot CLI | OTLP traces (`chat` spans), turned into logs by `spanlogs` | `github.copilot.nano_aiu` × 1e-11 | GitHub AI credits actually charged |
| VS Code | OTLP traces (`chat` spans), turned into logs by `spanlogs` | the Alloy price table (no `nano_aiu`) | Copilot per-token rates, which equal the API list prices for Claude and GPT |

Costs are list-price equivalents: on a subscription they measure usage, not the bill. Codex signed in with ChatGPT spends ChatGPT credits, which have no fixed USD value, so its cost is what the same tokens would cost on the API. The client-side settings that send each harness's telemetry live in the dotfiles repo.

#### Where one model's price differs

| Case | Handling |
|------|----------|
| Same model through the API and through Copilot | Copilot bills Claude and GPT at the API's per-token rates, so one row serves both. The one difference is GPT-5.6 Luna's long-context threshold (over 200K input on Copilot, over 272K on the API): its long-context rows are conditional on `service.name`. |
| Long-context tiers | Claude Haiku 5.5 over 100K prompt tokens, GPT-6, GPT-5.6, GPT-5.5 and GPT-5.4 over 272K, Grok 4.5 to 4.7 over 200K pay higher rates. A long-context row (prompt = `input_tokens` + `cache_read_tokens`) precedes the model's default row. Other Claude models price their full 1M context at the standard rate. |
| Cache writes | Claude and GPT-6, GPT-5.6 (API and Copilot) charge a cache write (Claude 1.25× input for 5 minutes, 2× for 1 hour; GPT 1.25× input). No harness that uses the table reports cache-write tokens (Codex reports total and cached input; Copilot spans carry `gen_ai.usage.cache_read.input_tokens` only), so the table bills them as uncached input. That understates a write by 0.25× input, and a 1-hour Claude write by 1×. Codex with ChatGPT credits has no cache-write charge. |
| Copilot auto model selection | Paid plans get 10% off model costs with auto selection. Copilot CLI's `nano_aiu` includes it; VS Code spans do not say whether auto picked the model, so its table cost can be up to 10% high. |
| Included or free models on Copilot | None: every chat model is billed in AI credits (code completions and next edit suggestions are not, and send no chat spans). VS Code's internal `gpt-4o-mini` calls are not on Copilot's price list; the VS Code Chat Debug View shows them at rate 0, so their row prices them at 0, on `copilot-chat` only. |
| Fast and priority modes, data residency | Not in the telemetry, so not priced: Claude fast mode is 2× on Opus 5.5, OpenAI Fast mode and regional endpoints cost more, Anthropic US-only inference is 1.1×. Copilot's Opus 4.8 fast mode has its own row. |
| Promotional prices | Copilot's Gemini rates are promotional: Gemini 4 Argon until 2026-12-01, Gemini 3.7 and 3.8 Flash until 2026-12-31. Recheck after those dates. |

#### Price table (USD per 1M tokens, checked 2026-10-17)

The rows in `agent_usage` are the source of truth; this mirrors them. Sources: [Anthropic pricing](https://platform.claude.com/docs/en/about-claude/pricing), [OpenAI API pricing](https://developers.openai.com/api/docs/pricing), [GitHub Copilot models and pricing](https://docs.github.com/en/copilot/reference/copilot-billing/models-and-pricing).

| Model | Input | Cache read | Cache write | Output | Long context (input / cache read / output) | Source |
|-------|------:|-----------:|------------:|-------:|---------------------------------------------|--------|
| Claude Fable 5.1 | 10 | 0.25 | 12.50 | 50 | — | Anthropic, Copilot |
| Claude Fable 5 | 10 | 1 | 12.50 | 50 | — | Anthropic, Copilot |
| Claude Opus 5.5 | 4 | 0.20 | 5 | 20 | — | Anthropic, Copilot |
| Claude Opus 5, 4.8, 4.7, 4.6, 4.5 | 5 | 0.50 | 6.25 | 25 | — | Anthropic (Copilot: 5, 4.8) |
| Claude Opus 4.8 fast mode | 10 | 1 | 12.50 | 50 | — | Copilot |
| Claude Sonnet 5.5 | 2 | 0.10 | 2.50 | 10 | — | Anthropic, Copilot |
| Claude Sonnet 5 | 2 | 0.20 | 2.50 | 10 | — | Anthropic, Copilot |
| Claude Sonnet 4.6, 4.5, 4 | 3 | 0.30 | 3.75 | 15 | — | Anthropic (Copilot: 4.6, 4) |
| Claude Haiku 5.5 | 0.10 | 0.01 | 0.125 | 0.50 | > 100K: 0.50 / 0.05 / 2.50 | Anthropic, Copilot |
| Claude Haiku 4.5 | 1 | 0.10 | 1.25 | 5 | — | Anthropic, Copilot |
| GPT-6.1 Sol | 2 | 0.10 | 2.50 | 10 | > 272K: 4 / 0.20 / 15 | OpenAI, Copilot |
| GPT-6 Sol | 2 | 0.20 | 2.50 | 10 | > 272K: 4 / 0.40 / 15 | OpenAI, Copilot |
| GPT-6 Luna | 0.10 | 0.01 | 0.125 | 0.50 | > 272K: 0.20 / 0.02 / 0.75 | OpenAI, Copilot |
| GPT-6 Astra | 10 | 1 | 12.50 | 50 | > 272K: 20 / 2 / 75 | OpenAI, Copilot |
| GPT-5.6 Sol | 4 | 0.40 | 5 | 20 | > 272K: 8 / 0.80 / 30 | OpenAI, Copilot |
| GPT-5.6 Terra | 2 | 0.20 | 2.50 | 12 | > 272K: 4 / 0.40 / 18 | OpenAI, Copilot |
| GPT-5.6 Luna | 0.20 | 0.02 | 0.25 | 1.20 | > 272K API, > 200K Copilot: 0.40 / 0.04 / 1.80 | OpenAI, Copilot |
| GPT-5.5 | 5 | 0.50 | — | 30 | > 272K: 10 / 1 / 45 | OpenAI, Copilot |
| GPT-5.4 | 2.50 | 0.25 | — | 15 | > 272K: 5 / 0.50 / 22.50 | OpenAI, Copilot |
| GPT-5.4 mini | 0.75 | 0.075 | — | 4.50 | — | OpenAI, Copilot |
| GPT-5.4 nano | 0.20 | 0.02 | — | 1.25 | — | OpenAI, Copilot |
| GPT-5 mini | 0.25 | 0.025 | — | 2 | — | OpenAI, Copilot |
| GPT-5.3-Codex | 1.75 | 0.175 | — | 14 | — | Copilot |
| Gemini 3.7 Flash, 3.8 Flash | 0.75 | 0.075 | — | 3.75 | — | Copilot (promotional) |
| Gemini 4 Argon | 2 | 0.10 | — | 10 | — | Copilot (promotional) |
| Grok 4.5, 4.6, 4.7 | 2 | 0.50 | — | 6 | > 200K: 4 / 1 / 12 | Copilot |
| Kimi K3 | 3 | 0.30 | — | 15 | — | Copilot |
| MAI-Code-1.1-Flash | 0.20 | 0.02 | — | 1.20 | — | Copilot |
| gpt-4o-mini (VS Code internal) | 0 | 0 | — | 0 | — | VS Code Chat Debug View |

Cache write is listed for reference; the table cannot bill it (see above). Codex's defaults are GPT-6.1 Sol (paid ChatGPT plans) and GPT-6 Luna (Free and Go).

**Update the price table** when a provider changes prices or a harness's default model changes:

1. Check the three pricing pages above (per 1M tokens: input, cache read, output, and any long-context threshold). Copilot-only models take Copilot's per-token rates, at 1 AI credit = $0.01. Leave out a model whose price no official page lists.
2. Edit the `PRICE TABLE` rows in `otelcol.processor.transform "agent_usage"` and the table above. The first matching row wins: put a long-context row before its default row and a specific model before a broader regex. A model with no row records tokens but no cost.
3. Ship it like any Alloy change (release PR, deploy), then check that `sum by (model) (count_over_time({service_name=~"codex|github-copilot|copilot-chat"} | agent_event="api_request" | cost_usd="" [1d]))` returns nothing for current models.

The daily budget is the `budget` variable on Agent Overview and the `agent-daily-cost` alert threshold (`grafana/provisioning/alerting/rules.yaml`); change both together.

### Data Sources (Pre-configured)
| Name | Type | URL |
|------|------|-----|
| Prometheus | prometheus | `http://observability-metrics-store:9090` |
| Loki | loki | `http://observability-log-store:3100` |
| Tempo | tempo | `http://observability-trace-store:3200` |

---

## Alerting

Both sources push to ntfy (`https://ntfy.<domain>`, publisher user `alerts`):

| Source | Topic | Covers | Routing |
|--------|-------|--------|---------|
| Grafana | `grafana` | App/DB/exporter/observability rules (Prometheus), HTTP 5xx + container error logs (Loki) | Priority from `severity` via ntfy template `grafana-alert` (critical 5, warning 4, resolved 3); 4h repeat |
| Netdata | `netdata` | Host + containers (temp, disk, RAM, OOM, `docker_container_unhealthy`) | Critical + clear only, no repeat |

Grafana's contact point and root policy are provisioned in `grafana/provisioning/alerting/{contact-points,policies}.yaml`; Netdata's in `infra/netdata/health_alarm_notify.conf`.

**Provisioned Alert Rules:**

| Group | Alerts |
|-------|--------|
| Database Alerts | PostgreSQL Down, PostgreSQL Low Cache Hit, MariaDB Down |
| Redis Alerts | Redis Down |
| Observability Stack | Loki Down, Tempo Down, Alloy Down |
| Agent Ops (Loki) | Agent Telemetry Silent (no `claude-code` events for 36h), Guard Deny Spike (>10 denies per guard rule in 1h), Agent Daily Cost (>$750 list price across harnesses in 24h), Agent Rate Limit Burst (>5 Claude Code 429s in 1h) |
| HTTP Errors (Loki) | Nginx 5xx Error Ratio High (per vhost, >5% and ≥20 errors over 5m), Container Error Logs Burst (>15 error lines/10m per service), Cloudflare Tunnel Origin Unreachable (>3 in 5m) |

The container-error rule relies on Alloy's regex-derived `level` label (`alloy/pipelines/logs.alloy`: `level=`, `[ERROR]`, cloudflared `ERR`, monolog `.ERROR:`, NestJS and ntfy formats). Add a pattern there when a new service logs in another format. The query excludes noisy technologies (`grafana`, `alloy`, `netdata`, `*-exporter`) and benign lines (`Unauthenticated`, `context canceled`, `unexpected EOF`). Container health/restarts are covered by Netdata, not Grafana.

Alert rules are provisioned via `grafana/provisioning/alerting/rules.yaml`. Removing a rule from the file does not delete it from Grafana: add its uid to `deleteRules` at the top of that file in the same change (e.g. `nginx-no-logs`, dropped in #362 because nginx is legitimately silent at night; Alloy Down / Loki Down cover a broken log pipeline).

---

## Troubleshooting

### Common Issues

**Logs not appearing in Loki:**
1. Check container has `com.giocaizzi.namespace` label
2. Verify Alloy can access Docker socket
3. Check Alloy logs: `docker service logs observability_alloy`

**Traces not appearing in Tempo:**
1. Verify OTLP endpoint configuration in application
2. Check Tempo is receiving data: `curl http://observability-trace-store:3200/ready`
3. Check Alloy OTLP receiver: `curl http://observability-collector:12345/metrics`

**Host `oom_kill` / `30min_ram_swapped_out` alerts (Netdata):**
1. Find who was killed: `ssh pi.local 'journalctl -k --since -2d | grep "Memory cgroup out of memory"'`. `constraint=CONSTRAINT_MEMCG` means one container hit its own `deploy.resources.limits.memory` (raise that limit); `CONSTRAINT_NONE` means the host ran out of RAM.
2. Find which containers sit at their limit: `grep '^max' /sys/fs/cgroup/system.slice/docker-<id>.scope/memory.events` counts limit hits; `memory.swap.current` in the same folder shows how much of the container is swapped out.
3. A container thrashing at its limit swaps in and out heavily, which also raises `30min_ram_swapped_out`; fix the limit first, the swap alert follows.

Host swap baseline (not managed by this repo): zram `/dev/zram0` 2 GiB (priority 100) plus `/swapfile` 16 GiB (priority -2), `vm.swappiness=60`. Check with `cat /proc/swaps /proc/sys/vm/swappiness`.

**High memory usage:**
- Reduce Loki retention period
- Adjust Prometheus scrape intervals
- Check Tempo trace sampling rate