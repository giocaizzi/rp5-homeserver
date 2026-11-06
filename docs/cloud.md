# Cloud Infrastructure

Terraform manages Cloudflare and GCP resources.

## What It Provisions

| Provider | Resource | Purpose |
|----------|----------|---------|
| Cloudflare | Zero Trust Tunnel | Secure external access without port forwarding |
| Cloudflare | DNS Records | Public domain routing (`*.<domain>`), CAA records |
| Cloudflare | Access apps and policies | Email-gated apps, path-scoped apps (service-token paths use Service Auth, a few paths bypass), per-app `session_duration` |
| Cloudflare | Service Tokens | One per machine client (MCP connectors, OTLP ingest, CRM API) |
| Cloudflare | Identity provider | Pocket ID login method for Access |
| Cloudflare | Zone settings (`cloud/zone.tf`) | TLS/HTTPS settings as code, HSTS |
| Cloudflare | DNSSEC (`cloud/zone.tf`) | Zone signing |
| Cloudflare | WAF custom rules (`cloud/waf.tf`) | Scanner paths, machine-only host allowlist |
| Cloudflare | Notification policies (`cloud/notifications.tf`) | Email alerts |
| GCP | GCS Bucket | Backup storage (Archive class) |
| GCP | Service Account | Backup credentials with minimal permissions |

## Setup

### 1. Prerequisites

- Cloudflare account with domain and Zero Trust enabled
- GCP project with billing enabled
- Terraform ≥ 1.6

### 2. Configure

```bash
cd cloud
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
- `cloudflare_api_token` — [Create token](https://dash.cloudflare.com/profile/api-tokens) with the permissions in [Token scopes](#token-scopes-and-rotation)
- `cloudflare_account_id`, `zone_id`, `zone_name` — From Cloudflare dashboard
- `tunnel_secret` — Generate: `openssl rand -base64 32`
- `gcp_project_id`, `gcp_backup_bucket_name` — Your GCP project and unique bucket name

### 3. Deploy

```bash
gcloud auth application-default login
terraform init
terraform apply
```

### 4. Extract Secrets

```bash
# Tunnel token for cloudflared
bws secret create infra_cloudflared_token "$(terraform output -raw tunnel_token)" <project-id>   # then sync_infra.sh

# GCP service account for Backrest
bws secret create infra_gcp_service_account "$(terraform output -raw backup_service_account_key | base64 -d)" <project-id>
```

Then sync infra: `BWS_ACCESS_TOKEN=<token from your keyring> PI_SSH_USER=<user> DOMAIN=<domain> ./scripts/sync_infra.sh`

## Token scopes and rotation

The Terraform token is account-owned. Permissions `cloud/` needs today:

| Permission | Used for |
|---|---|
| Zone: Zone Settings Write | zone settings, HSTS |
| Zone: DNS Write | DNS records, CAA, DNSSEC |
| Zone: Zone Read | zone lookup |
| Account: Cloudflare Tunnel Write | tunnel and its config |
| Account: Access: Apps and Policies Write | Access apps and policies |
| Account: Access: Service Tokens Write | service tokens |
| Account: Access: Organizations, Identity Providers, and Groups Write | Pocket ID identity provider |
| Account: Notifications Write | notification policies |
| Zone: Zone WAF Write | WAF custom rules |

Steps for the owner (dashboard only; nothing here changes tokens by itself):

1. **Split the token.** A read-only token (the same permissions as Read) for the `cloud-plan` environment, used by PR plans; the write token only on `cloud-production`.
2. **Remove unused scopes.** Drop MCP Portals Write from the write token: no portal resource lives in `cloud/`.
3. **Set an expiry (TTL)** on both tokens. No Free notification covers API token expiry: record the date and open a dated reminder issue for the rotation.
4. **Rotate:** create the new token, update the `CLOUDFLARE_API_TOKEN` secret on both environments, run a PR plan, then delete the old token. No client-IP filter: GitHub-hosted runners have no stable egress.

## Service token refresh

Service tokens last one year. Read the real `expires_at` from the dashboard (Access, Service Auth). Refresh with the dashboard **Refresh** button or the refresh API (+1 year); changing `duration` in Terraform also resets the expiry. Neither rotates the secret, so connectors keep working. Set a dated reminder issue per token batch.

## Runbooks

### HSTS

Set in `cloud/zone.tf` (`security_header`): `max_age` 6 months, no `includeSubDomains`, no preload. Browsers keep the policy until the last `max_age` they saw expires. Rollback: set `enabled = false` in a PR; browsers that saw the policy keep enforcing HTTPS until it expires, so no hostname can serve plain HTTP meanwhile.

### DNSSEC

1. Merging the PR signs the zone (`status = "active"`). Signing alone changes nothing for resolvers.
2. Read the DS record: dashboard (DNS, Settings), or `terraform output dnssec_ds` locally (sensitive).
3. Add the DS at the registrar (automatic only with Cloudflare Registrar).
4. Verify `dig DS <domain>` and a DNSSEC analyser. A wrong DS makes the whole domain SERVFAIL on validating resolvers.

Rollback: remove the DS at the registrar **first**, keep signing until the DS TTL expires (often 24-48 h), then set `status = "disabled"`.

### CAA

`cloud/zone.tf` sets `letsencrypt.org` and `pki.goog` at the apex. Cloudflare adds its other Universal SSL CAs automatically (not shown in the dashboard: `dig <domain> caa`). A certificate from another CA fails to issue; delete the record to roll back.

### Zone settings

Each setting is one `cloudflare_zone_setting`, codifying the live value (`ssl` strict, `min_tls_version` 1.2 for older e-readers, `tls_1_3` on without 0-RTT). `security_level` is not managed: it only toggles Under Attack mode. Removing a resource does not reset the live value.

### Access session duration

Set per app: 8 h for `code`, `portainer`, `backrest`, `openclaw`; 24 h for every other app. Service-token paths are unaffected. New apps must set `session_duration` explicitly.

### Cloudflare notifications

Terraform manages the email policies for tunnel health (this tunnel), Universal SSL and Cloudflare incidents. The destination is the `alert_email` input (secret `ALERT_EMAIL` on `cloud-plan` and `cloud-production`). Dashboard-managed, not in Terraform (do not recreate them): DDoS Protection, Expiring Service Token Alert, Leaked Service Token Alert. A webhook to ntfy is deliberately not used: it would be dead exactly when the tunnel is down.

### WAF custom rules

`cloud/waf.tf` holds the one `http_request_firewall_custom` ruleset (Free: 5 rules, no regex, no Log action). It runs before Access.

| Rule | Action | Matches |
|---|---|---|
| R1 | block | scanner and probe paths on every host (`/wp-`, `/.env`, `/.git`, `xmlrpc.php`, `phpmyadmin`, `/cgi-bin/`) |
| R2 | block | on `otel`, `netdata-mcp`, `langfuse-mcp`, `mcp-stdio`: any path nginx would 404 (`/v1/`, `/mcp`, `/api/public/mcp`, `*/mcp`), except `/cdn-cgi/` |

R2 mirrors the nginx `location` blocks: a new MCP path added in nginx needs the same change in R2. Rollback: set `enabled = false` on the rule, or revert. Check Security, Events after a change.

Rate limiting is not managed in Terraform: the single Free `http_ratelimit` slot is taken by a dashboard-managed rule ("Leaked credential check"), which Terraform must not touch.

## Troubleshooting

**`Error loading state ... UserProjectAccountProblem` (HTTP 403) on a local `terraform init`/`plan`.** Application Default Credentials bill Google API calls to a *quota project*: the one set by `gcloud auth application-default set-quota-project`, or the gcloud default project at login. If that project's billing account is closed, every call fails, including reading the state bucket, although the bucket's own project is fine. CI is unaffected (Workload Identity Federation has no user quota project). Point the quota project at this setup's GCP project for the session:

```bash
export GOOGLE_CLOUD_QUOTA_PROJECT=<gcp-project>   # the gcp_project_id in terraform.tfvars
terraform init -backend-config=backend.hcl -reconfigure
```

**`BWS_ACCESS_TOKEN` is empty but secrets sync works on CI or another shell.** The token is meant to live in the OS keyring and reach `sync_infra.sh`/`create_secrets.sh` only through the command's environment, so an interactive shell normally doesn't have it. Read it from the keyring inline for the one command instead of exporting it.

## Details

See [`cloud/README.md`](../cloud/README.md) for full configuration reference and security considerations.
