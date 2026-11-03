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
  sum(max_over_time(M[$__range]) - min_over_time(M[$__range]))
  ```
- Per-hour average = total divided by `($__range_s / 3600)`. `$__range_s` is the
  range in integer seconds (Grafana Prometheus macro).

## Host and session filtering

- Alloy promotes `host.name` onto metric datapoints as the `host_name` label. Filter
  Claude Code Prometheus metrics directly:
  ```
  M{job=~".*/claude-code", host_name=~"${host}(\\.local)?|", session_id=~"$session_id"}
  ```
- Filter metric labels directly; dashboard queries must remain valid as range queries
  without relying on target metadata series.
- `session_id` is structured metadata in Loki, not a stream label. Keep the Session
  selector as a textbox (default `.*`) and filter it in the pipeline.
- `model` is structured metadata in Loki, not a stream label. Keep the Model selector
  as a regex textbox (default `.*`), not `label_values` or a static model inventory.

## Loki panels

- Claude Code-only queries use
  `{service_name="claude-code", host_name=~"${host}(\\.local)?|"} | session_id=~"$session_id"`.
  Keep them simple and never join.

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

- One folder contains the unified agent dashboards. A signal lives on exactly one dashboard:
  cost, tokens, sessions and errors for every harness on Agent Overview; guard, skills and
  tool approvals on Agent Ops; cross-harness drill-down on Agents Detail. Claude Code-only
  panels belong on Agents Detail only when the signal has no harness-agnostic equivalent.
- Overview and Ops are harness-agnostic, Loki only. A model call is `agent_event="api_request" or event_name="api_request"`
  (the second covers Claude Code records from before the Alloy `agent_usage` transform).
- Every `unwrap` is followed by `| __error__=""`: harnesses leave fields such as `cost_usd`
  or `cache_creation_tokens` out, and the conversion error would otherwise show as a series.
- Schema and price table: `docs/monitoring.md`, Agent cost. Dashboard uids: `agents-overview`,
  `agents-ops`, `agents-detail` (`agents/detail.json`; Loki plus Claude Code-only Prometheus
  panels, following the data-model and selector rules above).
- Verify each query against live Loki (instant and range) before shipping.
