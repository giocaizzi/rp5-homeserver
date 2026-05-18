#!/usr/bin/env bash
# Idempotent one-time bootstrap for cloud/ Terraform CI/CD.
#
# Creates (or no-ops if present):
#   - GCS bucket for Terraform state (versioned, public-access-prevention enforced)
#   - Workload Identity Federation pool + GitHub OIDC provider, scoped to one
#     specific repo via attribute-condition
#   - terraform-ci service account
#   - IAM bindings: WIF principalSet → SA via roles/iam.workloadIdentityUser
#                   SA → project roles needed for Terraform plan/apply
#
# Requires:
#   - gcloud authenticated as a project owner (or roles equivalent to
#     resourcemanager.projectIamAdmin + iam.workloadIdentityPoolAdmin +
#     iam.serviceAccountAdmin + storage.admin)
#   - bash 4+, set GCP_PROJECT_ID and GITHUB_REPO before running.
#
# Usage:
#   GCP_PROJECT_ID=my-project GITHUB_REPO=giocaizzi/rp5-homeserver \
#     ./scripts/bootstrap_cloud_cicd.sh
#
# Re-running is safe: every gcloud call is wrapped to ignore "already exists".

set -euo pipefail

: "${GCP_PROJECT_ID:?GCP_PROJECT_ID required}"
: "${GITHUB_REPO:?GITHUB_REPO required (e.g. giocaizzi/rp5-homeserver)}"

REGION="${REGION:-europe-west1}"
STATE_BUCKET="${STATE_BUCKET:-${GCP_PROJECT_ID}-tfstate}"
POOL_ID="${POOL_ID:-github}"
PROVIDER_ID="${PROVIDER_ID:-github-provider}"
SA_ID="${SA_ID:-terraform-ci}"
SA_EMAIL="${SA_ID}@${GCP_PROJECT_ID}.iam.gserviceaccount.com"

ok()    { printf "  \033[0;32m✓\033[0m %s\n" "$*"; }
info()  { printf "\033[0;34m▸\033[0m %s\n" "$*"; }
warn()  { printf "  \033[1;33m!\033[0m %s\n" "$*"; }

ignore_exists() {
  # Run "$@"; if it fails because resource already exists, succeed silently.
  if ! out=$("$@" 2>&1); then
    if grep -qiE 'already exists|ALREADY_EXISTS|Operation finished successfully' <<<"$out"; then
      return 0
    fi
    printf '%s\n' "$out" >&2
    return 1
  fi
}

# ---------- State bucket ----------
info "State bucket: gs://${STATE_BUCKET}"
if gcloud storage buckets describe "gs://${STATE_BUCKET}" --project="$GCP_PROJECT_ID" >/dev/null 2>&1; then
  ok "exists"
else
  gcloud storage buckets create "gs://${STATE_BUCKET}" \
    --project="$GCP_PROJECT_ID" \
    --location="$REGION" \
    --uniform-bucket-level-access \
    --public-access-prevention >/dev/null
  ok "created"
fi
gcloud storage buckets update "gs://${STATE_BUCKET}" --versioning >/dev/null
ok "versioning on"

# ---------- WIF pool ----------
info "WIF pool: ${POOL_ID}"
ignore_exists gcloud iam workload-identity-pools create "$POOL_ID" \
  --project="$GCP_PROJECT_ID" \
  --location=global \
  --display-name="GitHub Actions" >/dev/null
ok "pool ready"

PROJECT_NUM=$(gcloud projects describe "$GCP_PROJECT_ID" --format='value(projectNumber)')
POOL_NAME="projects/${PROJECT_NUM}/locations/global/workloadIdentityPools/${POOL_ID}"

# ---------- WIF provider ----------
info "WIF provider: ${PROVIDER_ID} (locked to repo ${GITHUB_REPO})"
ignore_exists gcloud iam workload-identity-pools providers create-oidc "$PROVIDER_ID" \
  --project="$GCP_PROJECT_ID" \
  --location=global \
  --workload-identity-pool="$POOL_ID" \
  --display-name="GitHub OIDC" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.ref=assertion.ref" \
  --attribute-condition="attribute.repository == '${GITHUB_REPO}'" >/dev/null
ok "provider ready"

PROVIDER_FQN="${POOL_NAME}/providers/${PROVIDER_ID}"

# ---------- Service account ----------
info "Service account: ${SA_EMAIL}"
ignore_exists gcloud iam service-accounts create "$SA_ID" \
  --project="$GCP_PROJECT_ID" \
  --display-name="Terraform CI" >/dev/null
ok "SA ready"

# ---------- WIF → SA binding ----------
info "Binding WIF principalSet → SA (workloadIdentityUser)"
gcloud iam service-accounts add-iam-policy-binding "$SA_EMAIL" \
  --project="$GCP_PROJECT_ID" \
  --role=roles/iam.workloadIdentityUser \
  --member="principalSet://iam.googleapis.com/${POOL_NAME}/attribute.repository/${GITHUB_REPO}" \
  >/dev/null
ok "bound"

# ---------- Project IAM for the SA ----------
# Roles required to manage the resources currently in cloud/main.tf
# (GCS backup bucket + SA + key, IAM bindings). Tighten if you scope down.
ROLES=(
  roles/storage.admin               # state bucket + backup bucket
  roles/iam.serviceAccountAdmin     # create backup SA
  roles/iam.serviceAccountKeyAdmin  # create backup SA key
  roles/resourcemanager.projectIamAdmin  # bind backup SA → bucket
)
info "Granting roles to ${SA_EMAIL} on project ${GCP_PROJECT_ID}"
for role in "${ROLES[@]}"; do
  gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="$role" \
    --condition=None \
    >/dev/null
  ok "$role"
done

# ---------- Output GH env config ----------
cat <<EOF

────────────────────────────────────────────────────────────
Bootstrap complete. Wire up GitHub next:

GitHub Actions repository variables (Settings → Variables → Actions):
  TF_STATE_BUCKET           ${STATE_BUCKET}
  GCP_WIF_PROVIDER          ${PROVIDER_FQN}
  GCP_TF_SERVICE_ACCOUNT    ${SA_EMAIL}
  GCP_PROJECT_ID            ${GCP_PROJECT_ID}
  GCP_REGION                ${REGION}
  GCP_BACKUP_BUCKET_NAME    <copy from cloud/terraform.tfvars>
  CLOUDFLARE_ACCOUNT_ID     <copy from cloud/terraform.tfvars>
  CLOUDFLARE_ZONE_NAME      <copy from cloud/terraform.tfvars>
  CLOUDFLARE_ZONE_ID        <copy from cloud/terraform.tfvars>
  BACKUP_RETENTION_DAYS     <copy from cloud/terraform.tfvars>
  N8N_USERS                 <JSON array string, e.g. ["a@x.com"]>
  PORTAINER_USERS           <JSON array string>
  BACKREST_USERS            <JSON array string>
  FIREFLY_USERS             <JSON array string>
  HOMEPAGE_USERS            <JSON array string>
  OPENCLAW_USERS            <JSON array string>
  TF_VERSION                1.9.8 (optional override)

GitHub Environments to create (Settings → Environments):
  cloud-plan        — variables/secrets above; no required reviewers
  cloud-production  — same variables/secrets; toggle Required reviewers
                      if you want a human approval gate before apply.

GitHub Actions repository SECRETS (Settings → Secrets → Actions):
  CLOUDFLARE_API_TOKEN      <your CF API token>
  TUNNEL_SECRET             <openssl rand -base64 32 of the existing tunnel>

Migrate local state to GCS (run from your workstation, one time):
  cd cloud
  cat > backend.hcl <<HCL
  bucket = "${STATE_BUCKET}"
  HCL
  terraform init -migrate-state -backend-config=backend.hcl
  rm terraform.tfstate terraform.tfstate.backup terraform.tfstate.*.backup

After migration, gitignore backend.hcl locally (already covered by *.hcl in
cloud/.gitignore if you choose to add it — otherwise add a one-liner).

Branch ruleset — add one rule to the existing "main" ruleset
(Settings → Rules → main → Add rule):

  Require status checks to pass
    Status checks that are required:
      gate   (GitHub Actions)
    Require branches to be up to date before merging: off

Optional extra secret-scanning toggles (Settings → Code security):
  - Secret scanning · Non-provider patterns        → enabled
  - Secret scanning · Validity checks              → enabled
────────────────────────────────────────────────────────────
EOF
