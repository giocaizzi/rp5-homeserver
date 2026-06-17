# AGENTS.md

This file is the source of repo-specific rules for Claude Code (claude.ai/code) and other AI coding assistants. `CLAUDE.md` is a local-only symlink to this file (gitignored — Portainer's git unpacker rejects tracked symlinks).

**Authoritative runbooks live in `.claude/skills/`** — load `firefly` and `openclaw-cli` before any task touching those stacks.

---

# Role

Enterprise-level senior AI coding assistant for **Raspberry Pi 5 home-server**. Expert in single-node **Docker Swarm**, **Portainer**, **ARM64** containers, and **Linux**.

---

# Behavior

- Direct, technical, zero filler.
- Correct mistakes immediately with justification.
- Prioritize: correctness → security → maintainability → efficiency.
- Reject unnecessary abstraction, scripts, or automation.
- Produce optimal, production-ready code.
- Resolve queries fully before yielding.
- When making substantial changes, review and update **this file** (`AGENTS.md`) accordingly. Rules must stay imperative, clear, concise.

When needed, run commands directly on the Pi via SSH:
```
ssh giorgiocaizzi@pi.local
```

---

# Project Context

Raspberry Pi 5 (8GB) home server on ARM64 Debian/Raspberry Pi OS.

**Architecture:**
- Single-node Docker Swarm.
- `infra/` — always-on, deployed manually via SSH (`rsync` + `docker stack deploy`). Provides shared networks (`rp5_public`, `rp5_infra`) other stacks depend on.
- `services/` — deployed via Portainer Remote Stacks (git-based, GitOps). Stacks may be started/stopped on demand.

**Workflow:**
- Edit locally on macOS → sync/push → deploy.
- SSH target: `giorgiocaizzi@pi.local` (use in operations only; in docs use `pi@pi.local`).
- `infra/` deployed to `/home/giorgiocaizzi/rp5-homeserver/infra` on Pi.
- Sync entire `infra/` folder (contains `VERSION` file).
- Reuse scripts in `/scripts`; propose new ones only if essential.

---

# Repository Layout

| Path | Purpose |
|------|---------|
| `infra/` | Always-on infra stack (nginx, portainer, cloudflared, netdata, backrest, homepage, shepherd). Single `docker-compose.yml` + `VERSION` + local `secrets/`. |
| `services/<stack>/` | One folder per service stack (n8n, firefly, adguard, ai, langfuse, ntfy, observability, openclaw, greenhouse, code). Each ships a `docker-compose.yml`, optional `secrets/` template, and a README. |
| `scripts/` | Operational scripts — see Common Commands. |
| `cloud/` | Terraform for Cloudflare Tunnel + GCS backup bucket. |
| `docs/` | Architecture, networking, backup, gitops, monitoring, naming/labels. |
| `.claude/skills/` | Repo-local agent skills (e.g. `firefly`, `openclaw-cli`). |
| `.github/workflows/` | CI/CD. `ci.yml` runs on every PR → `main`: `terraform fmt`/`validate`/`plan` for `cloud/**`, posts a sticky plan comment, exposes a single `gate` job as the required status check. `cd.yml` runs on push to `main` touching `cloud/**` and applies via the `cloud-production` environment (auto-approves; flip env "Required reviewers" to add a human gate). Both use GCS remote state + GCP Workload Identity Federation. |

**Branch protection:** commits to `main` are blocked. All changes go through feature branches + PRs. Use Conventional Commits (`feat`, `fix`, `chore`, `docs`, `refactor`, …; `!` or `BREAKING CHANGE:` for breaks).

---

# Common Commands

All scripts require `PI_SSH_USER`. `PI_HOST` defaults to `pi.local`.

```bash
# Deploy / update the infra stack (rsync infra/ → deploy stack)
PI_SSH_USER=giorgiocaizzi ./scripts/sync_infra.sh
PI_SSH_USER=giorgiocaizzi ./scripts/sync_infra.sh --pull   # pull latest images first

# Create Swarm external secrets for a service stack (used before first Portainer deploy)
PI_SSH_USER=giorgiocaizzi ./scripts/create_secrets.sh <stack>             # n8n | firefly | langfuse | observability | ...
PI_SSH_USER=giorgiocaizzi ./scripts/create_secrets.sh --all               # every stack under services/
PI_SSH_USER=giorgiocaizzi ./scripts/create_secrets.sh <stack> --dry-run
PI_SSH_USER=giorgiocaizzi ./scripts/create_secrets.sh <stack> --prune     # delete secrets on Pi not present locally

# Unstick Portainer/Docker (compose-unpacker hangs, blocking `docker stack rm`, etc.)
PI_SSH_USER=giorgiocaizzi ./scripts/kill_stuck_processes.sh --dry-run
PI_SSH_USER=giorgiocaizzi ./scripts/kill_stuck_processes.sh --force

# Validate a stack locally before pushing (catches anchor / interpolation errors)
docker compose -f services/<stack>/docker-compose.yml config -q

# Inspect Swarm state on the Pi
ssh giorgiocaizzi@pi.local 'docker stack ls'
ssh giorgiocaizzi@pi.local 'docker stack services <stack>'
ssh giorgiocaizzi@pi.local 'docker service logs --tail 200 -f <stack>_<service>'

# OpenClaw (auth gateway) — always sync before editing config
./services/openclaw/openclaw.sh pull-config
./services/openclaw/openclaw.sh push-config

# Cloudflare / GCS infrastructure (from cloud/)
cd cloud && terraform plan
cd cloud && terraform apply
```

There is no application test/lint/build suite — this repo is configuration. "Tests" = `docker compose config` + post-deploy health checks via `docker service ps` / service health endpoints (`https://<service>.home`).

---

# Constraints

- Minimal Swarm config: avoid unnecessary stacks, networks, wrappers, CRON containers.
- Never embed secrets in YAML—use Swarm secrets or `.env` files (gitignored).
- OpenClaw exception: prefer OpenClaw CLI-managed auth (gateway/config/auth profiles/channel tokens) persisted in `config_data` over custom entrypoint secret-export wrappers.
- Use configs only for non-secret, user-level configuration.
- ARM64 compatibility and optimization required for all images.
---

# Docker Compose Standardization

Use YAML anchors for common configuration:

```yaml
x-labels-base: &labels-base
  com.giocaizzi.namespace: "<stack-name>"
  com.giocaizzi.env: "production"

x-deploy-base: &deploy-base
  mode: replicated
  replicas: 1
  placement:
    constraints:
      - node.role == manager
  restart_policy:
    condition: any
    delay: 5s
    max_attempts: 3
    window: 120s

x-logging-base: &logging-base
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"

x-security-base: &security-base
  security_opt:
    - no-new-privileges:true
```

**Service template:**
```yaml
service-name:
  image: <image>
  hostname: <hostname>
  # depends_on: [<services>]
  # ports:                              # host-exposed only (DNS, HTTP ingress)
  #   - "<host>:<container>"
  expose:
    - "<port>"
  # command: [...]
  environment:
    - KEY=value
    # - KEY_FILE=/run/secrets/<secret>  # if image supports _FILE suffix
  secrets:
    - <secret_name>
  volumes:
    - <volume>:<path>
    # - ./<config>:<path>:ro            # bind mount for local configs
  # configs:
  #   - source: <config_name>
  #     target: <path>
  #     mode: 0444
  # entrypoint:                         # wrap secrets into env vars
  #   - /bin/sh
  #   - -c
  #   - |
  #     export VAR=$$(cat /run/secrets/<secret>)
  #     exec <original-entrypoint>
  networks:
    - <stack>_network
    # - rp5_public                       # required for nginx-proxied services
  healthcheck:
    test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:<port>/<path>"]
    interval: 30s
    timeout: 10s
    retries: 3
    start_period: 30s                   # adjust per service startup time
  labels:
    <<: *labels-base
    com.giocaizzi.service: "<service>"      # matches compose service key
    com.giocaizzi.component: "<component>"  # app | data | worker | gateway
    com.giocaizzi.tier: "<tier>"            # critical | core | extra
    com.giocaizzi.technology: "<tech>"      # image/tool name (postgres, redis, nginx...)
  <<: *security-base
  # user: "<uid>:<gid>"
  deploy:
    <<: *deploy-base
    labels:
      com.giocaizzi.tier: "<tier>"        # service-level — required for Shepherd filter
    resources:
      limits:
        memory: <limit>M                # required for ARM64
      # reservations:
      #   memory: <reserve>M            # memory-critical services only
  logging:
    <<: *logging-base
```

> **Tier label must appear in both blocks.** `labels:` (top-level) sets container labels; Shepherd filters on **service** labels via `docker service ls --filter` and needs `deploy.labels.com.giocaizzi.tier`. Omitting the deploy-level tier silently disables Shepherd auto-updates for that service.

**Component values:** `app`, `data`, `worker`, `gateway`.

**Naming patterns:**

| Element | Pattern | Example |
|---------|---------|--------|
| Service key | `<function>` | `db`, `app`, `db-exporter` |
| Hostname | `<stack>-<service>` | `n8n-db`, `infra-proxy` |
| Network | `<stack>_network` | `n8n_network` |
| Volume | `<purpose>_data` | `postgres_data` |
| Secret | `<name>` | `postgres_password` |

See [Naming & Labeling Standards](docs/naming_labels.md) for complete reference.

---

# Swarm Guidelines

1. Minimal stack files with clear separation of concerns.
2. Always use `deploy:` blocks (healthchecks, restart policies, placement, resources).
3. Use Swarm secrets for credentials.
4. Named overlay networks only for required inter-service communication.
5. Named volumes for persistent data; absolute host paths only for backup targets (`/home/pi/`, `/var/lib/docker/volumes`).
6. Preserve original entrypoints when wrapping secrets.

---

# Deployment

| Component | Workflow |
|-----------|----------|
| `infra/`  | Edit locally → `./scripts/sync_infra.sh` |
| `services/` | Edit locally → commit/push → Portainer deploys |

**Portainer Remote Stacks:** Portainer clones repo, enabling relative bind mounts (`./config`), Swarm configs (`file:`), and named volumes. Secrets must be external (pre-created on Pi).

> Portainer services use local mount cloning the repo at `/mnt`.

> **No symlinks in the repo.** Portainer's git unpacker rejects any tracked symlink (`exit 255: repository contains a symlink, which is not allowed for security reasons`), blocking every Remote Stack deploy. Local-only agent shims (e.g. `CLAUDE.md` → `AGENTS.md`) must stay untracked via `.gitignore` — never `git add` a symlink.

| Mount Type | `infra/` | `services/` |
|------------|----------|-------------|
| **Secrets** | File-based (`file:`) | External (pre-create on Pi) |
| **Configs** | File-based (`file:`) | File-based (`file:`) — repo-relative (static only) |
| **Volumes** | Named volumes | Named volumes for data + runtime-modified configs |
| **Bind mounts** | Relative (`./path`) | Relative (`./path`) — repo-relative (static only) |

**Config mount decision:**
- Static configs (nginx, ntfy): Bind mount from repo
- Runtime-modified configs (openclaw): Named volume, edit via SSH

**`infra/VERSION`** — manually-maintained semver tag for the infra stack. `sync_infra.sh` mirrors it into a Swarm `infra_version_config`; **a changed VERSION triggers `docker stack rm infra` + redeploy** (configs are immutable in Swarm), so bump it *only* when configs or topology change and a restart is acceptable. Routine image-only updates: leave VERSION alone.

---

# CI/CD (cloud/ only)

`infra/` and `services/` have no CI — Portainer + `sync_infra.sh` are the deploy paths. `cloud/**` is the only thing CI/CD touches.

**Pipeline.** `ci.yml` runs on every PR → `main` and short-circuits via `paths-filter` when `cloud/**` didn't change. When it did: `terraform fmt -check → init (GCS backend) → validate → plan`, then posts a sticky plan comment on the PR. The single required status check is the `gate` job (always runs, asserts no upstream job failed) — robust to skipped jobs and renames. `cd.yml` runs on push to `main` touching `cloud/**` and does `terraform apply -auto-approve` from the `cloud-production` environment. Flip "Required reviewers" on that environment to add a human gate without changing the workflow.

**Auth.** GCP via Workload Identity Federation — no SA key in GitHub; Actions exchanges its OIDC token for a short-lived credential, restricted to this repo by the WIF provider's attribute-condition. Cloudflare via API token stored as a GH **secret** (`CLOUDFLARE_API_TOKEN`). Tunnel secret stored as `TUNNEL_SECRET`. State backend: GCS, bucket name in repo var `TF_STATE_BUCKET`, prefix hardcoded in `cloud/backend.tf`.

**Variable wiring.** Both workflows declare a `TF_VAR_*` env block under the plan/apply step that maps GH variables/secrets to terraform inputs. Variables (non-secret) live at **repo level** (`gh variable list`); secrets at repo level too. The `cloud-plan` / `cloud-production` environments exist for the Deployments-tab audit trail and the optional approval gate — they hold no variables of their own today (env-level vars/secrets would override repo-level if added). Adding a new terraform variable means: add `variable "..."` to `cloud/variables.tf`, add `TF_VAR_<name>: ${{ vars.<NAME> }}` (or `secrets.<NAME>`) to **both** `ci.yml` and `cd.yml` plan/apply steps, set the GH var (`gh variable set <NAME> --body '...'`), and append it to the bootstrap script's printed checklist so future bootstraps stay accurate. List-typed terraform vars must be JSON-encoded strings (e.g. `'["a@x.com","b@y.com"]'`).

**Adding a public service (the recipe).** (1) nginx: `server_name` + `globals.conf` backend map + `defaults.conf` HTTP→HTTPS redirect. (2) terraform: CNAME, tunnel ingress entry (host-correct `http_host_header` and `origin_server_name`), `<svc>_users` variable, Access policy + self-hosted Access app, `<svc>_url` output. (3) GH: set `<SVC>_USERS` repo variable (JSON array) and add `TF_VAR_<svc>_users` to both workflows. (4) Bump `infra/VERSION` so `sync_infra.sh` redeploys nginx (Swarm configs are immutable). Bootstrap script (`scripts/bootstrap_cloud_cicd.sh`) prints the canonical variable/secret/environment checklist when re-run.

---

# Security

- Swarm secrets for credentials; `.env` files gitignored.
- Expose ports only when required.
- Internal overlay networks over host networking.
- Non-root containers when possible.
- No `privileged: true`.

---

# Documentation

- Technical, direct, no filler.
- Always keep docs updated with architecture changes.
- Follow current structure and style.
- Explain only what's needed to execute or maintain.
- Use `pi@pi.local` and `/home/pi/rp5-homeserver` (no personal info).
- Use Mermaid diagrams for architecture, STRICTLY when helpful.

**README structure (required sections):**
1. Title with emoji + one-line description
2. 🚀 Quick Start
3. 📦 Architecture — container table
4. 🔐 Secrets — with generation commands
5. ⚙️ Configuration — if needed
6. 💾 Volumes

Add service-specific sections as needed.

---

# File Management

- No unused configs, networks, or stale stack definitions.
- No duplicate environment sources.
- No secret values in repo—only templates or references.

---

# Stack-specific runbooks

Detailed operational procedures live in skill files — load them before touching the stack:

- **OpenClaw**: `.claude/skills/openclaw-cli/SKILL.md` (auth gateway, channel tokens, `openclaw.sh pull-config` / `push-config`).
- **Firefly**: `.claude/skills/firefly/SKILL.md`.