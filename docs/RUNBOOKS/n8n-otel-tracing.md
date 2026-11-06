# n8n OpenTelemetry tracing

**When:** you want to see n8n workflow runs as traces in Grafana (Tempo), or to turn that off. Not for n8n's own product telemetry (`N8N_DIAGNOSTICS_ENABLED=false`, unrelated). Background: [monitoring](../monitoring.md) (Tempo, Alloy). n8n's tracing is a Preview feature (since 2.19) and may change.
**Preconditions:** the `observability` stack running (collector `observability-collector`, OTLP gRPC on 4317 inside the `rp5_observability` overlay, no auth); n8n 2.39 or later (gRPC transport).

## Steps
1. The wiring is in [services/n8n/docker-compose.yml](../../services/n8n/docker-compose.yml): the `app` service is on `rp5_observability` and sets `N8N_OTEL_ENABLED=true`, `N8N_OTEL_EXPORTER_OTLP_PROTOCOL=grpc`, `N8N_OTEL_EXPORTER_OTLP_ENDPOINT=http://observability-collector:4317` and `N8N_OTEL_EXPORTER_SERVICE_NAME=n8n`.
2. Deploy as usual (merge, then the n8n service release triggers the Portainer webhook). n8n restarts, so running executions and webhooks are interrupted for about a minute.
3. Defaults worth knowing (from the n8n docs): only **production** executions are traced (manual test runs are not; `N8N_OTEL_TRACES_PRODUCTION_ONLY`), node spans are on (`N8N_OTEL_TRACES_INCLUDE_NODE_SPANS`), sampling is 100% (`N8N_OTEL_TRACES_SAMPLE_RATE`). Agent prompts and tool inputs/outputs are **not** recorded (`N8N_AGENTS_TRACING_RECORD_INPUTS` and `_OUTPUTS` set to `false`); set them to `true` only if you accept prompts in Tempo.

## Verify
1. Logs show no OTel startup error: `ssh pi@pi.local 'docker service logs --tail 100 n8n_app 2>&1 | grep -i -E "otel|opentelemetry"'`.
2. Run any workflow that is active (scheduled or webhook) once.
3. In Grafana, Explore, datasource Tempo: search by `service.name = n8n`; the trace has a `workflow.execute` span with `node.execute` children.

## Rollback
Set `N8N_OTEL_ENABLED=false` (or remove the `N8N_OTEL_*` lines and the `observability_network` entry from `app`) and redeploy. Nothing else changes; stored traces expire with Tempo's retention.

**Last verified:** not yet verified after deploy
