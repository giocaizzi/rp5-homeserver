# Service Auth migration (WIP, not implemented)

Status: design note. Nothing here is applied.

## What and why

Every service-token Access policy in `cloud/main.tf` uses `decision = "bypass"`. Cloudflare
documents that bypass skips all Access controls and the request is **not logged**, and recommends
Service Auth (`non_identity`) for machine clients. Today, therefore:

- service-token calls (MCP connectors, OTLP ingest) leave no Access log;
- they carry no Access JWT, so nginx skips these paths (`$cf_access_bypass`, see
  [access-jwt.md](../access-jwt.md)) and relies on app-level auth.

Switching a policy to Service Auth gives Access logs and a JWT with the path app's `aud`, so nginx
can verify the call instead of skipping it.

## Shape: one cloud + infra pair per app

The `cf_access` secret format (one `aud` per path-scoped app), the `$cf_access_bypass` skip list
and the verifier's `aud` lookup all change, so each app is two PRs, in order:

1. `feat(cloud)`: switch that app's policy from `bypass` to `non_identity`. nginx still skips the
   path, so this is safe on its own.
2. `feat(infra)`: stop skipping the path, add its `aud` to the secret, verify in `log` mode, then
   switch to `enforce`. An infra release applies it.

Start with one low-stakes app (`netdata-mcp`), then proceed app by app. Excluded: policies that are
bypass for a reason other than a service token (IP-scoped `crm` MCP bypass, the everyone-bypass on
Calibre device paths).

## Risks

- A connector that sends the token but handles redirects differently from a browser: check the
  connector Worker logs after each app.
- A stale or missing `aud` in the `cf_access` secret makes nginx reject valid calls once enforced.
- Service Auth requires the token headers on every call; a client that relied on bypass ignoring
  them could break.

## Rollback

Per app: revert the `feat(cloud)` PR (policy back to `bypass`); if the infra PR already enforces,
revert it first and cut an infra release, or set the host back to `log`/`off` in
`$cf_access_mode`.

## Open before starting

- Decide whether to start now or after the zone hardening items settle.
- Confirm the Access log retention available on the plan, so the new logs are actually useful.
