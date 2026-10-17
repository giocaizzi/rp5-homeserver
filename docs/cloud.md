# Cloud Infrastructure

Terraform manages Cloudflare and GCP resources.

## What It Provisions

| Provider | Resource | Purpose |
|----------|----------|---------|
| Cloudflare | Zero Trust Tunnel | Secure external access without port forwarding |
| Cloudflare | DNS Records | Public domain routing (`*.yourdomain.com`) |
| Cloudflare | Access Policies | Email-based authentication for exposed services |
| Cloudflare | Service Token | GitOps webhook authentication |
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
- `cloudflare_api_token` — [Create token](https://dash.cloudflare.com/profile/api-tokens) with Zone/DNS/Tunnel/Access permissions
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

## Troubleshooting

**`Error loading state ... UserProjectAccountProblem` (HTTP 403) on a local `terraform init`/`plan`.** Application Default Credentials bill Google API calls to a *quota project*: the one set by `gcloud auth application-default set-quota-project`, or the gcloud default project at login. If that project's billing account is closed, every call fails, including reading the state bucket, although the bucket's own project is fine. CI is unaffected (Workload Identity Federation has no user quota project). Point the quota project at this setup's GCP project for the session:

```bash
export GOOGLE_CLOUD_QUOTA_PROJECT=<gcp-project>   # the gcp_project_id in terraform.tfvars
terraform init -backend-config=backend.hcl -reconfigure
```

**`BWS_ACCESS_TOKEN` is empty but secrets sync works on CI or another shell.** The token is meant to live in the OS keyring and reach `sync_infra.sh`/`create_secrets.sh` only through the command's environment, so an interactive shell normally doesn't have it. Read it from the keyring inline for the one command instead of exporting it.

## Details

See [`cloud/README.md`](../cloud/README.md) for full configuration reference and security considerations.
