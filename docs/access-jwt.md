# Cloudflare Access JWT at nginx

Cloudflare Access gates the public hosts at the edge, but anything that reaches nginx directly on 443 (a LAN device, any container on the Docker networks) can send `Host: <svc>.<domain>` and skip it. nginx closes that gap by verifying the `Cf-Access-Jwt-Assertion` header Access adds to every request it lets through (#393).

## How it works

| Piece | Role |
|---|---|
| `infra/nginx/njs/cf_access.js` | Verifier (njs). RS256 signature against the team's JWKS (`https://<team>.cloudflareaccess.com/cdn-cgi/access/certs`, cached 1 h in a shared dict, refetched on an unknown `kid`), `iss`, `exp`/`nbf` (60 s skew) and the host's `aud` tag. |
| `infra/nginx/snippets/cf-access.conf` | `auth_request` to the verifier. Included in every public server block that has a host-wide Access app or a Service Auth path. |
| `infra/nginx/conf.d/cf-access.conf` | The per-host flag (`$cf_access_mode`: `off` / `log` / `enforce`), the Service Auth paths (`$cf_access_app`: host + path to the path-scoped app key, and `$cf_access_app_mode`: that app's own mode) and the paths Access bypasses (`$cf_access_bypass`). |
| Swarm secret `cf_access_v3` (BWS key `infra_cf_access_v3`, mounted at `/run/secrets/cf_access`) | `{"team_domain": "<team>.cloudflareaccess.com", "aud": {"<subdomain>": "<aud tag>", "<path app key>": "<aud tag>"}}`. Private: never committed. |

Modes:

- `off`: allowed, nothing read or fetched. Every listed host is `enforce` since 2026-10-17; a new host starts at `log`.
- `log`: checked, always allowed; a failure writes a `cf_access log: <reason> (host=... path=... app=... client=...)` warning (`app=-` outside Service Auth paths) to the nginx error log.
- `enforce`: checked; no token gets 401, any other failure (bad signature, wrong `aud`, expired, verifier error) gets 403. Failures are logged as `cf_access enforce: ...`.

`*.home` LAN names are never checked: they map to `off` whatever the flag says, and the `$cf_access_app` patterns exclude them.

A **Service Auth path** is a path-scoped Access app whose policy is Service Auth (`non_identity`): Access issues a JWT for a valid service token, and its `aud` is that path app's own tag. `$cf_access_app` maps `$host$uri` to the app key (the first label of the app's `name` in `cloud/main.tf`), the verifier looks that key up in the secret's `aud` map instead of the host's subdomain, and `$cf_access_app_mode` gives the path its own mode. That mode wins over the host's `$cf_access_mode`, so an enforced UI host keeps enforcing while its MCP paths are in `log`. A host without a host-wide app (`otel`, `netdata-mcp`, `langfuse-mcp`) stays `off` as a whole; only its mapped path is checked. Keep both maps in sync with `cloud/main.tf`.

### Hosts and paths

Access issues no JWT for a request let through by a **bypass** policy, so those paths are skipped by the verifier (`$cf_access_bypass`) and keep their app-level auth as the gate. Only the IP and everyone policies below remain bypass.

| Host | Access app | Service Auth paths (checked: own `aud`, mode per path) | Paths skipped (Access bypass) |
|---|---|---|---|
| `portainer` | users | `/mcp` (`portainer-mcp`) | none |
| `backrest`, `homepage`, `code`, `miniflux` | users | none | none |
| `n8n` | users | `/mcp-server` (`n8n-mcp`) | `/webhook/` (everyone; the WAF allows only Telegram's networks, [runbook](./RUNBOOKS/n8n-telegram-webhook.md)) |
| `firefly` | users | `/api/v1/mcp` (`firefly-mcp`) | none |
| `grafana` | users | `/mcp` (`grafana-mcp`) | none |
| `greenhouse` | users | `/mcp` (`greenhouse-mcp`) | none |
| `crm` | users | `/rest` (`crm-api`) | `/mcp`, `/oauth`, `/.well-known/oauth-protected-resource`, `/.well-known/oauth-authorization-server` (IP: Anthropic egress ranges `160.79.104.0/21` and `153.61.208.0/20`, [published list](https://platform.claude.com/docs/en/api/ip-addresses)) |
| `calibre` | users | none | `/opds`, `/kosync`, `/kobo` (everyone) |
| `mcp-stdio` | owner | `/fli/mcp`, `/garmin/mcp`, `/surfline/mcp`, `/lamma/mcp` (`fli-mcp`, `garmin-mcp`, `surfline-mcp`, `lamma-mcp`) | none |
| `otel` | no host-wide app | `/v1/` (`otel-ingest`) | none |
| `netdata-mcp` | no host-wide app | `/mcp` (`netdata-mcp`) | none |
| `langfuse-mcp` | no host-wide app | `/api/public/mcp` (`langfuse-mcp`) | none |
| `ntfy`, `id` | no host-wide app | none | not checked (not in the flag map) |

When a path-scoped Access app is added or changed in `cloud/main.tf`, update `$cf_access_app` / `$cf_access_app_mode` (Service Auth) or `$cf_access_bypass` (bypass) in the same change, and bump the secret if it gains an `aud`.

## One-time setup

1. Create the config secret from Terraform state (run in `cloud/`, with the team name in `CF_ACCESS_TEAM`; the value is never printed). Every Access application is keyed by the first label of its `name`: host-wide apps are named `<subdomain>.<zone>`, path-scoped apps `<key>.<zone>` (for example `grafana-mcp`), as `cloud/main.tf` names them all:

   ```bash
   bws secret create infra_cf_access_v3 "$(terraform show -json | jq -c --arg team "$CF_ACCESS_TEAM" '
     {team_domain: ($team + ".cloudflareaccess.com"),
      aud: ([.values.root_module.resources[]
             | select(.type == "cloudflare_zero_trust_access_application")
             | {key: (.values.name | split(".")[0]), value: .values.aud}] | from_entries)}')" <project-id>
   ```

2. Add the team name and every `aud` tag to the `LEAK_PATTERNS` secret (repo and Dependabot), as for any private value.
3. Write the secret file on the Pi before the infra release that ships the `cf_access` secret, or that deploy fails on the missing file: `BWS_ACCESS_TOKEN=<token> PI_SSH_USER=pi DOMAIN=<domain> ./scripts/sync_infra.sh`.

Docker secrets are immutable: when an `aud` changes (an app recreated) or a host is added, bump the secret's version suffix (next: `cf_access_v4`, file `./secrets/cf_access_v4.json`, BWS key `infra_cf_access_v4`) and point the proxy's `source:` at it in the same infra change; keep `target: cf_access` so the verifier's path stays put.

## Service Auth paths (log -> enforce)

The 13 path-scoped service-token apps (`$cf_access_app`) start in `log` in `$cf_access_app_mode`. Roll them out in this order:

1. Create the BWS secret `infra_cf_access_v3` with the jq under [One-time setup](#one-time-setup), from the `cloud/` Terraform state after the Service Auth change is applied (the path apps' `aud` tags must exist).
2. Add the new `aud` tags to `LEAK_PATTERNS` (repo and Dependabot).
3. Run a non-local `PI_SSH_USER=pi DOMAIN=<domain> ./scripts/sync_infra.sh` to write `./secrets/cf_access_v3.json` on the Pi **before** step 4; otherwise `deploy-infra` fails on the missing file.
4. Cut the infra release.

**Verify (at least 24 h of normal MCP and OTLP use).** Failures on these paths, in Loki (`service_name="proxy"` is the nginx container) or straight from the service log:

```logql
{service_name="proxy"} |= "cf_access log" != "app=- "
```

```bash
ssh pi@pi.local 'docker service logs --since 24h infra_proxy 2>&1 | grep "cf_access log" | grep -v "app=- "'
```

Good is zero lines for real clients. Otherwise:

- `wrong aud`: the secret holds a stale `aud` for that app key; recreate the secret as the next version.
- `no aud configured for host`: the app key is missing from the secret.
- `missing token`: Access is not issuing a JWT for the path (policy still bypass, or not Service Auth) or the client does not go through Access.

Prove the gate from the LAN: a request without a JWT must log `cf_access log: missing token ... app=grafana-mcp`:

```bash
curl -sk -o /dev/null -w '%{http_code}\n' --resolve grafana.<domain>:443:<pi-ip> https://grafana.<domain>/mcp
```

**Enforce.** Set the app keys to `enforce` in `$cf_access_app_mode` (`feat(infra): enforce the Access JWT on <svc> service-token paths`), cut the infra release, repeat the LAN curl (now 401) and watch `cf_access enforce` lines for a day.

**Rollback.** Set the app keys back to `log` in `$cf_access_app_mode` and release. To revert the cloud change (policy back to bypass), first put the path back into `$cf_access_bypass` (a bypass policy issues no JWT, so a checked path would fail), release, and only then apply the cloud revert.

## Rollout (one host at a time)

Start with a low-traffic host without bypassed paths (`homepage`, then `backrest`, `code`), then the hosts with bypassed paths. For each host:

1. **Log.** Set the host to `log` in `infra/nginx/conf.d/cf-access.conf`, land it as `fix(infra): log the Access JWT check on <svc>` and cut the infra release (`sync_infra.sh` runs `nginx -t` and reloads).
2. **Verify.** Use the host normally (browser, apps, MCP clients, sync clients) for at least a day, then check that no failures were logged for legitimate traffic:

   ```bash
   ssh pi@pi.local 'docker service logs --since 24h infra_proxy 2>&1 | grep "cf_access log" | grep "host=<svc>\."'
   ```

   Expected: nothing, or only `missing token` from clients you know reach nginx directly. A `wrong aud` means the secret's `aud` for that host is stale; a `missing token` on a path real clients use means a bypass entry is missing.
3. **Prove the gate.** From the LAN, a direct request without a JWT must show up as a failure:

   ```bash
   curl -sk -o /dev/null -w '%{http_code}\n' --resolve <svc>.<domain>:443:<pi-ip> https://<svc>.<domain>/
   ```

   In `log` mode this is still allowed and logs `cf_access log: missing token`.
4. **Enforce.** Set the host to `enforce`, land and release the same way. Repeat step 3: it now returns 401. Check through Access (browser and any service-token or bypassed path the host has) that everything still works, and watch `cf_access enforce` lines for a day.

## Rollback

- **Fast (on the Pi, minutes):** edit the bind-mounted flag and reload; the next infra release overwrites it, so follow up with the PR below.

  ```bash
  ssh pi@pi.local
  sed -i 's/^\(    <svc>\.\* *\)enforce;/\1off;/' ~/rp5-homeserver/infra/nginx/conf.d/cf-access.conf
  docker exec "$(docker ps -q -f label=com.docker.swarm.service.name=infra_proxy | head -n1)" nginx -t
  docker exec "$(docker ps -q -f label=com.docker.swarm.service.name=infra_proxy | head -n1)" nginx -s reload
  ```

- **Durable:** set the host back to `log` or `off` in `conf.d/cf-access.conf` (`fix(infra): ...`) and cut the infra release.

A host locked out (every request 403 with `wrong aud`, or 403 with `error: certs fetch ...` when the Pi cannot reach `<team>.cloudflareaccess.com`) is the expected failure mode of a wrong secret or broken egress: roll that host back, fix the cause, and restart from `log`.
