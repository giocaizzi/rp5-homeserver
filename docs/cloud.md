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
terraform output -raw cloudflare_tunnel_token > ../infra/secrets/cloudflared_token.txt

# GCP service account for Backrest
terraform output -raw backup_service_account_key | base64 -d > ../infra/secrets/gcp_service_account.json

# GitOps service token (for GitHub Actions)
terraform output cf_access_client_id
terraform output cf_access_client_secret
```

Then sync infra: `./scripts/sync_infra.sh`

## Details

See [`cloud/README.md`](../cloud/README.md) for full configuration reference and security considerations.
