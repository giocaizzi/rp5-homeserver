# Remote state backend.
#
# Partial config: the bucket name is supplied at init time so the same code
# works on a workstation and in CI without committing project-specific names.
#
# Workstation:
#   terraform -chdir=cloud init -backend-config=backend.hcl
#   (backend.hcl is gitignored; format: bucket = "<your-tfstate-bucket>")
#
# CI: see .github/workflows/cloud-ci.yml — bucket comes from `vars.TF_STATE_BUCKET`.
#
# One-time bootstrap (state bucket + WIF + GH wiring) is in
# scripts/bootstrap_cloud_cicd.sh.
terraform {
  backend "gcs" {
    prefix = "rp5-homeserver"
  }
}
