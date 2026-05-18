# Cloud Infrastructure

Terraform configuration for managing Cloudflare and GCP resources for the home server.

## Overview

**Cloudflare:**
- Zero Trust tunnel for secure service access
- DNS records for exposed services  
- Access policies with email authentication
- No port forwarding required

**GCP:**
- Archive storage bucket for backups
- Service account with minimal permissions
- IP-based access control
- Versioning and flexible retention policies

## Architecture

```
Internet → Cloudflare Edge → Encrypted Tunnel → Home Server → Services (n8n, etc.)
                                                      ↓
                                               Backrest (Restic)
                                                      ↓
                                           GCS Archive Bucket (IP-restricted)
```

## Prerequisites

1. **Cloudflare account** with your domain and Zero Trust enabled
2. **GCP account** with billing enabled and active project
3. **Terraform >= 1.6** installed
4. **gcloud CLI** for GCP authentication (optional)

## Setup

### 1. Create Configuration File

```bash
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars
```

**Cloudflare Configuration:**
- `cloudflare_api_token` - Create at [API Tokens](https://dash.cloudflare.com/profile/api-tokens)

   > **Required Permissions:** 
   > - `Zone:Zone Settings:Edit`
   > - `Zone:Zone:Read`
   > - `Zone:DNS:Edit` 
   > - `Account:Cloudflare Tunnel:Edit`
   > - `Account:Access: Apps and Policies:Edit`
   > - `Account:Access: Service Tokens:Edit` *(required for GitOps webhooks)*

- `cloudflare_account_id` - From Cloudflare dashboard
- `zone_name` - Your domain (e.g., example.com)
- `zone_id` - From domain overview
- `tunnel_secret` - Generate: `openssl rand -base64 32`
- `n8n_users` - Email addresses for n8n access

**GCP Configuration:**
- `gcp_project_id` - Your GCP project ID
- `gcp_region` - Region (default: europe-west1)
- `gcp_backup_bucket_name` - Globally unique bucket name
- `backup_retention_days` - Set to `0` for Backrest-managed retention (recommended)

### 2. Authenticate with GCP

```bash
gcloud auth application-default login
```

### 3. Deploy Cloud Infrastructure

```bash
terraform init -backend-config=backend.hcl   # bucket = "<your-tfstate-bucket>"
terraform apply
```

> **State lives in GCS.** First-time setup must run [`scripts/bootstrap_cloud_cicd.sh`](../scripts/bootstrap_cloud_cicd.sh) — see [CI/CD](#-cicd) below. Create `cloud/backend.hcl` (gitignored as `*.hcl`) containing `bucket = "<your-tfstate-bucket>"`.

### 4. Extract Outputs

Extract terraform tokens:
```bash
terraform output -raw cloudflare_tunnel_credentials
# copy this to ../infra/.env
```

Extract Service Account Key:
```bash
terraform output -raw backup_service_account_key | base64 -d > ../infra/secrets/gcp_service_account.json
```

### 5. Re-start infrastructure

```bash
ssh pi@pi.local "cd ~/rp5-homeserver/infra && docker stack rm infra && sleep 10 && docker stack deploy -c docker-compose.yml infra"
```



## Cloudflare 

**Zero Trust Tunnel:**
- Secure access to home server services
- No public IP exposure

**DNS Configuration:**
- Automatic DNS record management
- Proxying for enhanced security
- Application-level access control

## GCS Backup Bucket

**Storage Class: ARCHIVE**
- Lowest cost
- Perfect for infrequent backup access
- Retrieval latency: minutes to hours

**Retention Strategies:**

*Backrest-Managed (Recommended):*
```hcl
backup_retention_days = 0
```
- Backrest controls retention via Web UI
- Fine-grained policies (7 daily, 4 weekly, 6 monthly, 2 yearly)
- No automatic GCS deletion

*GCS Lifecycle Deletion:*
```hcl
backup_retention_days = 730  # 2 years
```
- GCS automatically deletes files older than N days
- Safety net on top of Backrest on consumption

**Security:**
- Public access prevention enforced - no public access possible
- Access exclusively via service account credentials
- Service account has objectAdmin role (read/write only for backups)
- Credentials secured on home server at `infra/backup/secrets/gcp_service_account.json`

> **Note:** GCS does not support IP-based restrictions via IAM. Access control relies on securing the service account credentials. Only systems with valid credentials can access the bucket.

---

## 🚦 CI/CD

Two workflows manage this directory:

| Workflow | Trigger | What it does |
|---|---|---|
| [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) | PR (any branch → `main`) | `terraform fmt -check`, `init`, `validate`, `plan`. Posts the plan as a sticky PR comment. The `gate` job is the **single required status check** — it always runs and asserts that nothing failed, so it stays correct even when there are no `cloud/**` changes. |
| [`.github/workflows/cd.yml`](../.github/workflows/cd.yml) | Push to `main` touching `cloud/**` | `terraform apply -auto-approve` inside the `cloud-production` environment. Toggle "Required reviewers" on that environment to add a human approval gate without changing the workflow. |

Auth model:

- **GCP**: Workload Identity Federation. No service-account key stored in GitHub — Actions exchanges its OIDC token for a short-lived SA credential. The WIF provider's `attribute-condition` restricts it to this exact repo.
- **Cloudflare**: API token stored as a per-environment GH secret.

State backend: GCS, partial config. Bucket name lives in repo variable `TF_STATE_BUCKET`, prefix is hardcoded in `backend.tf`.

### First-time bootstrap

One time, as a project owner on the GCP project:

```bash
GCP_PROJECT_ID=<your-project> GITHUB_REPO=giocaizzi/rp5-homeserver \
  ./scripts/bootstrap_cloud_cicd.sh
```

The script is idempotent. It prints the exact list of GitHub variables, secrets, environments, and the `gh api` ruleset patch you need to run afterwards.

### Local-state → GCS migration (one time)

After bootstrap, on the workstation where the existing `cloud/terraform.tfstate` lives:

```bash
cd cloud
echo 'bucket = "<your-tfstate-bucket>"' > backend.hcl
terraform init -migrate-state -backend-config=backend.hcl
rm terraform.tfstate terraform.tfstate.backup terraform.tfstate.*.backup
```

`backend.hcl` is gitignored. The local state files should be deleted only after the migration is confirmed by `terraform plan` returning a clean diff.

### Required status check

The branch ruleset is patched (via `gh api`, instructions printed by the bootstrap script) so `main` requires the `gate` job to pass before merge. `gate` is the only required check name — robust to future workflow restructuring.