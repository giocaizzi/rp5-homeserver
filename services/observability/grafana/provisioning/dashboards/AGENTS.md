# AGENTS.md — Grafana dashboard authoring (agent telemetry)

Scope: authoring/maintaining the dashboard JSON in this folder. For stack-wide
rules (Swarm, Portainer, secrets) see the repo-root `AGENTS.md`.

---

## Data model

- `claude_code_*_total` are **per-session counters**. Every `session_id` is its own
  series that starts at 0, only rises during that session, then goes stale.
  Sessions churn constantly — there is no single monotonic counter to range over.
- **NEVER** use `increase()`/`rate()` on a TOTAL over a range. Extrapolation across
  churning session series massively inflates results (observed: `increase[24h]`
  ≈ $344 vs true ≈ $95).
- Compute a total as a windowed delta summed across series:
  ```
  sum( (max_over_time(M[$__range]) - min_over_time(M[$__range])) * <host-join> )
  ```
- Per-hour average = total divided by `($__range_s / 3600)`. `$__range_s` is the
  range in integer seconds (Grafana Prometheus macro).

## The `target_info` host-filter join

- Resource attributes (`host.name`, `service.version`, `os.version`, …) are **not**
  labels on each metric — Alloy's Prometheus exporter puts them only in `target_info`.
  Filter by host via a join.
- **ALWAYS** write the join as:
  ```
  * on (job) group_left() max by (job) (target_info{host_name=~"$host_name"})
  ```
- **NEVER** write `* on (job, instance) group_left() target_info{...}`. It returns
  **HTTP 422 as a RANGE query**: multiple Claude Code versions emit duplicate
  `target_info` series per `(job,instance)` (identity includes
  service_version/os_version). `max by (job)` collapses that churn. Instant queries
  mask the bug; range queries — i.e. real panels — fail.
- Alloy now also promotes `host.name` onto every metric datapoint going forward
  (uniform `host_name` label), but historical series predating that change lack it
  on some metrics. Keep using the join for robustness.

## Loki panels

- Filter `service_name="claude-code"` and **never** join. Keep them simple.

---

## Provisioning & deploy

- Dashboards are bind-mounted **read-only** into Grafana from this repo path. The
  stack deploys via Portainer Remote Stack (GitOps from `main`): edit JSON here →
  merge to `main` → Portainer re-clones.
- **Portainer bind-mount inode trap:** after a re-clone the running Grafana
  container's bind mount can point at a deleted inode (provisioning dir empties).
  Fix by re-resolving the mount:
  ```
  ssh pi@pi.local 'docker service update --force observability_dashboard'
  ```
- Fixed datasource uids: `prometheus`, `loki`, `tempo`.

---

## Conventions

- Validate JSON before commit: `python3 -m json.tool dashboard.json >/dev/null`.
- Verify every Prometheus expr as a **RANGE query** against live Prometheus
  (container `observability_metrics-store`) before shipping — a query that works
  instant can still 422 as a range.
- Use `$__rate_interval` / `$__interval` for time-series panels; `$__range` /
  `$__range_s` for totals and averages.
- Claude Code exports metrics every 60s. A per-interval Prometheus panel (`max - min`,
  `rate`, `increase`, `changes` over `$__rate_interval`) needs panel `"interval": "2m"`,
  or each window holds one sample and the panel is flat or empty.

---

## Agents folder (`agents/`)

- One folder for every agent dashboard. A signal lives on exactly one dashboard: cost, tokens,
  sessions and errors for every harness on Agent Overview; guard, skills, tool approvals and
  subagents on Agent Ops; signals only Claude Code emits on Claude Code (detail). Add a panel
  to the detail dashboard only when no harness-agnostic equivalent exists.
- Overview and Ops are harness-agnostic, Loki only. A model call is `agent_event="api_request" or event_name="api_request"`
  (the second covers Claude Code records from before the Alloy `agent_usage` transform).
- Every `unwrap` is followed by `| __error__=""`: harnesses leave fields such as `cost_usd`
  or `cache_creation_tokens` out, and the conversion error would otherwise show as a series.
- Schema and price table: `docs/monitoring.md`, Agent cost. Dashboard uids: `agents-overview`, `agents-ops`,
  `claude-code-obs` (`agents/claude-code.json`, Prometheus + Loki; the Data model and join rules above apply).
- Verify each query against live Loki (instant and range) before shipping.
