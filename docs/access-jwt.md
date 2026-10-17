# Cloudflare Access JWT at nginx

Cloudflare Access gates the public hosts at the edge, but anything that reaches nginx directly on 443 (a LAN device, any container on the Docker networks) can send `Host: <svc>.<domain>` and skip it. nginx closes that gap by verifying the `Cf-Access-Jwt-Assertion` header Access adds to every request it lets through (#393).

## How it works

| Piece | Role |
|---|---|
| `infra/nginx/njs/cf_access.js` | Verifier (njs). RS256 signature against the team's JWKS (`https://<team>.cloudflareaccess.com/cdn-cgi/access/certs`, cached 1 h in a shared dict, refetched on an unknown `kid`), `iss`, `exp`/`nbf` (60 s skew) and the host's `aud` tag. |
| `infra/nginx/snippets/cf-access.conf` | `auth_request` to the verifier. Included in every public server block that has a host-wide Access app. |
| `infra/nginx/conf.d/cf-access.conf` | The per-host flag (`$cf_access_mode`: `off` / `log` / `enforce`) and the paths Access bypasses (`$cf_access_bypass`). |
| Swarm secret `cf_access` (BWS key `infra_cf_access`) | `{"team_domain": "<team>.cloudflareaccess.com", "aud": {"<subdomain>": "<aud tag>", ...}}`. Private: never committed. |

Modes:

- `off`: allowed, nothing read or fetched. Every listed host is `enforce` since 2026-10-17; a new host starts at `log`.
- `log`: checked, always allowed; a failure writes a `cf_access log: <reason> (host=... path=... client=...)` warning to the nginx error log.
- `enforce`: checked; no token gets 401, any other failure (bad signature, wrong `aud`, expired, verifier error) gets 403. Failures are logged as `cf_access enforce: ...`.

`*.home` LAN names are never checked: they map to `off` whatever the flag says.

### Hosts and bypassed paths

Access issues no JWT for a request let through by a **bypass** policy, so these paths are skipped by the verifier (`$cf_access_bypass`) and keep their app-level auth as the gate. Every MCP service-token policy in `cloud/main.tf` is `decision = "bypass"`, so service-token calls carry no JWT either.

| Host | Access app | Paths skipped (Access bypass) |
|---|---|---|
| `portainer` | users | `/mcp` (service token) |
| `backrest`, `homepage`, `openclaw`, `code` | users | none |
| `n8n` | users | `/mcp-server` (service token) |
| `firefly` | users | `/api/v1/mcp` (service token) |
| `grafana` | users | `/mcp` (service token) |
| `greenhouse` | users | `/mcp` (service token or users) |
| `crm` | users | `/rest` (service token or users); `/mcp`, `/oauth`, `/.well-known/oauth-protected-resource`, `/.well-known/oauth-authorization-server` (claude.ai egress IPs) |
| `calibre` | users | `/opds`, `/kosync`, `/kobo` (everyone) |
| `mcp-stdio` | owner | `/fli/mcp`, `/garmin/mcp` (service token); one entry per path-scoped server app |
| `otel`, `ntfy`, `netdata-mcp`, `langfuse-mcp` | no host-wide app | not checked (not in the flag map) |

When a path-scoped Access app is added or changed in `cloud/main.tf`, update `$cf_access_bypass` in the same change. Switching an MCP policy from `bypass` to Service Auth (`non_identity`) would make Access issue a JWT for it (with that path app's `aud`); the skip entry and the `aud` lookup would then need to change with it.

## One-time setup

1. Create the config secret from Terraform state (run in `cloud/`, with the team name in `CF_ACCESS_TEAM`; the value is never printed). Each host-wide app's `aud` is keyed by its subdomain; path-scoped apps (their `domain` contains a `/`) are left out:

   ```bash
   bws secret create infra_cf_access "$(terraform show -json | jq -c --arg team "$CF_ACCESS_TEAM" '
     {team_domain: ($team + ".cloudflareaccess.com"),
      aud: ([.values.root_module.resources[]
             | select(.type == "cloudflare_zero_trust_access_application")
             | select(.values.domain != null and (.values.domain | test("/") | not))
             | {key: (.values.domain | split(".")[0]), value: .values.aud}] | from_entries)}')" <project-id>
   ```

2. Add the team name and every `aud` tag to the `LEAK_PATTERNS` secret (repo and Dependabot), as for any private value.
3. Write the secret file on the Pi before the infra release that ships the `cf_access` secret, or that deploy fails on the missing file: `BWS_ACCESS_TOKEN=<token> PI_SSH_USER=pi DOMAIN=<domain> ./scripts/sync_infra.sh`.

Docker secrets are immutable: when an `aud` changes (an app recreated) or a host is added, rename the secret (`cf_access_v2`, file `./secrets/cf_access_v2.json`, BWS key `infra_cf_access_v2`) and point the proxy at it in the same infra change.

## Rollout (one host at a time)

Start with a low-traffic host without bypassed paths (`homepage`, then `backrest`, `code`, `openclaw`), then the hosts with bypassed paths. For each host:

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
