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
- `infra/` — always-on. Deployed by `deploy-infra.yml` on the **`infra` release**, on a **self-hosted runner on the Pi** (`sync_infra.sh --local`); also deployable manually (`workflow_dispatch`, or SSH `rsync` + `docker stack deploy`). Provides shared networks (`rp5_public`, `rp5_infra`) other stacks depend on.
- `services/` — deployed via Portainer Remote Stacks (git-based, GitOps), triggered by `deploy-services.yml` on each **service release** (per-stack Portainer webhook). Stacks may be started/stopped on demand.

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
| `services/<stack>/` | One folder per service stack (n8n, firefly, adguard, ai, langfuse, ntfy, observability, openclaw, greenhouse). Each ships a `docker-compose.yml`, optional `secrets/` template, and a README. |
| `scripts/` | Operational scripts — see Common Commands. |
| `cloud/` | Terraform for Cloudflare Tunnel + GCS backup bucket. |
| `docs/` | Architecture, networking, backup, gitops, monitoring, naming/labels. |
| `.claude/skills/` | Repo-local agent skills (e.g. `firefly`, `openclaw-cli`). |
| `.github/workflows/` | CI/CD. **`ci.yml`** (PR → `main`): `terraform fmt`/`validate`/`plan` for `cloud/**`, sticky plan comment, single `gate` required check. **`pr-title.yml`** (PR): scoped Conventional-Commit title lint. **`release-please.yml`** (push `main`): versioning/changelogs/tags only (App-token; no deploys). **`apply-cloud.yml`** (push `cloud/**`): `terraform apply` via `cloud-production` env (GCS state + GCP WIF) — Terraform stays plan-reviewed-on-merge. **`deploy-infra.yml`** (on **`infra` release**): self-hosted Pi runner, `sync_infra.sh --local`, env `pi-production`. **`deploy-services.yml`** (on **service release**): per-released-stack Portainer webhook on the Pi runner, env `pi-services`. Deploy envs expose the Deployments-tab audit + optional "Required reviewers" gate. Full flow: [Releases](docs/releases.md). |

**Branch protection:** commits to `main` are blocked. All changes go through feature branches + PRs. **Every PR title and commit subject MUST be `type(scope): description`** — a Conventional Commit with a mandatory scope — because release-please parses them to version + changelog each component. The exact format, scope vocabulary, and enforcement layers are in [Pull requests & commit titles](#pull-requests--commit-titles--mandatory-format).

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
| `infra/`  | **`infra` release** (`v*`) → `deploy-infra.yml` (Pi runner, `sync_infra.sh --local`). Manual: `workflow_dispatch`, or `PI_SSH_USER=<user> ./scripts/sync_infra.sh` |
| `services/` | **service release** (`<stack>-v*`) → `deploy-services.yml` fires that stack's Portainer webhook |
| `cloud/` | Push `cloud/**` → `apply-cloud.yml` (`terraform apply`, plan-reviewed-on-merge) |

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

**`infra/VERSION`** — the infra stack's version, now **owned by release-please** (it is the `infra` package's `version-file`, the bare `vX.Y.Z` main line, seeded at `1.13.0`). **Do not hand-edit it** — release-please overwrites it from `.release-please-manifest.json`. It bumps when an **infra Release PR merges**, i.e. when a releasing-type commit (`feat`/`fix`/`refactor`/`perf`) scoped to `infra/**` lands. `sync_infra.sh` mirrors it into a Swarm `infra_version_config`; **a changed VERSION triggers `docker stack rm infra` + redeploy** (configs are immutable in Swarm). Consequence: cutting an infra release implies an infra redeploy on the next `sync_infra.sh`. To change `infra/**` *without* bumping VERSION (and so without forcing a redeploy), use a non-releasing type — `chore(infra):` / `docs(infra):`.

---

# CI/CD

Six GitHub Actions workflows. Versioning/tagging (`release-please.yml`, `pr-title.yml`) and the PR gate (`ci.yml`) run off PRs/`main`; the **runtime deploys are release-gated** (`deploy-infra.yml`, `deploy-services.yml`), while `cloud/` Terraform stays apply-on-merge (`apply-cloud.yml`). Full release/versioning flow: **[docs/releases.md](docs/releases.md)**; deploy setup: [docs/gitops.md](docs/gitops.md).

**`cloud/` (apply-on-merge).** `ci.yml` runs on every PR → `main` and short-circuits via `paths-filter` when `cloud/**` didn't change. When it did: `terraform fmt -check → init (GCS backend) → validate → plan`, then posts a sticky plan comment on the PR. The single required status check is the `gate` job (always runs, asserts no upstream job failed) — robust to skipped jobs and renames. `apply-cloud.yml` (formerly `cd.yml`) runs on push to `main` touching `cloud/**` and does `terraform apply -auto-approve` from the `cloud-production` environment. Terraform stays **plan-reviewed-on-merge, not release-gated** (release-gating IaC would let `main` diverge from applied infra). Flip "Required reviewers" on that environment to add a human gate.

**`infra/` (release-gated).** `deploy-infra.yml` fires when release-please publishes the **`infra` release** (the bare `v*` tag), on a **self-hosted runner on the Pi** (label `rp5`, installed via `scripts/setup_pi_runner.sh`). It runs `sync_infra.sh --local` (no SSH — already on the Pi). `--local` mode excludes `secrets/` from the `rsync --delete` (secrets are gitignored, live only on the Pi). Env `pi-production`; needs repo var `PI_DEPLOY_USER`. Triggers only on `release`/`workflow_dispatch`, never `pull_request`, so fork code never runs on the Pi.

**`services/` (release-gated).** `deploy-services.yml` fires when release-please publishes a **service release** (`<stack>-v*`): a `detect` job parses the stack name from the tag, then a matrix `deploy` job runs on the **Pi self-hosted runner** and POSTs that stack's Portainer GitOps webhook **locally** (resolves the Portainer host to loopback → nginx → Portainer, never leaving the Pi). This sidesteps Cloudflare's WAF, which 403s GitHub's cloud egress IPs even with a valid CF Access service token. Non-service releases (`infra`, `cloud`, `mcp-connector`) no-op. Env `pi-services`; needs secrets `PORTAINER_URL` and `WEBHOOK_ID_<STACK>` per stack. Each service stack must be set to **Webhook** (not Polling) GitOps auto-update in Portainer. Adding a stack: add the secret **and** a `WEBHOOK_ID_<STACK>` line to the deploy job env.

**Auth (cloud/).** GCP via Workload Identity Federation — no SA key in GitHub; Actions exchanges its OIDC token for a short-lived credential, restricted to this repo by the WIF provider's attribute-condition. Cloudflare via API token stored as a GH **secret** (`CLOUDFLARE_API_TOKEN`). Tunnel secret stored as `TUNNEL_SECRET`. State backend: GCS, bucket name in repo var `TF_STATE_BUCKET`, prefix hardcoded in `cloud/backend.tf`.

**Variable wiring.** Both workflows declare a `TF_VAR_*` env block under the plan/apply step that maps GH variables/secrets to terraform inputs. Variables (non-secret) live at **repo level** (`gh variable list`); secrets at repo level too. The `cloud-plan` / `cloud-production` environments exist for the Deployments-tab audit trail and the optional approval gate — they hold no variables of their own today (env-level vars/secrets would override repo-level if added). Adding a new terraform variable means: add `variable "..."` to `cloud/variables.tf`, add `TF_VAR_<name>: ${{ vars.<NAME> }}` (or `secrets.<NAME>`) to **both** `ci.yml` and `apply-cloud.yml` plan/apply steps, set the GH var (`gh variable set <NAME> --body '...'`), and append it to the bootstrap script's printed checklist so future bootstraps stay accurate. List-typed terraform vars must be JSON-encoded strings (e.g. `'["a@x.com","b@y.com"]'`).

**Adding a public service (the recipe).** (1) nginx: `server_name` + `globals.conf` backend map + `defaults.conf` HTTP→HTTPS redirect. (2) terraform: CNAME, tunnel ingress entry (host-correct `http_host_header` and `origin_server_name`), `<svc>_users` variable, Access policy + self-hosted Access app, `<svc>_url` output. (3) GH: set `<SVC>_USERS` repo variable (JSON array) and add `TF_VAR_<svc>_users` to both `ci.yml` and `apply-cloud.yml`. (4) Land the nginx change as `feat(infra):`/`fix(infra):` and **cut the infra release** — that bumps `infra/VERSION`, which makes `deploy-infra.yml` (`sync_infra.sh`) redeploy nginx (Swarm configs are immutable). Do not hand-edit VERSION. Bootstrap script (`scripts/bootstrap_cloud_cicd.sh`) prints the canonical variable/secret/environment checklist when re-run.

---

# Pull requests & commit titles — MANDATORY format

**Every PR title and every commit subject MUST be `type(scope): description`** — a [Conventional Commit](https://www.conventionalcommits.org) **with a mandatory scope**. This is not optional. `main` is **squash-only** with `squash_merge_commit_title=PR_TITLE`, so **the PR title becomes the commit subject release-please parses on `main`**. A malformed or unscoped title silently misattributes — or drops — the release.

- **`type`** ∈ `feat` · `fix` · `perf` · `refactor` · `revert` · `docs` · `style` · `test` · `build` · `ci` · `chore`. The type drives the bump: `feat` → MINOR, `fix`/`perf`/`refactor`/`revert` → PATCH, `feat!` or a `BREAKING CHANGE:` footer → MAJOR; `docs`/`style`/`test`/`build`/`ci`/`chore` → no bump.
- **`scope`** (REQUIRED) — any lowercase token (`[a-z][a-z0-9-]*`); **not an allowlist** (release-please attributes releases by file **path**, not scope, so the scope is advisory). Pick it to communicate *what changed*:
  - a **release-please component** when the PR touches that path — `infra` (the **main `vX.Y.Z` line**, `infra/VERSION`), `cloud`, `mcp-connector` (`workers/`), or a service (`greenhouse`, `n8n`, …). Keep each PR to a **single** component so the version + changelog land on the right one.
  - a **meta scope** for cross-cutting work that touches no component → no release: `cicd` (`.github/workflows/**`, deploy scripts), `repo` (root docs, `scripts/`, tooling), `deps` (dependency bumps), etc.
- **`description`** — imperative, lowercase first word, no trailing period.
- Breaking change: add `!` after the scope (`feat(greenhouse)!: …`) and/or a `BREAKING CHANGE:` footer.

Examples: `feat(greenhouse): add humidity sensor` · `fix(infra): correct nginx healthcheck` · `ci(repo): add pr-title lint` · `chore(openclaw)!: drop legacy auth`.

Enforced on **three** layers: the **`pr-title.yml`** workflow (a plain regex — no third-party action) validates every PR title; the **`conventional-commit-guard.sh`** `PreToolUse` hook (wired per-developer in the gitignored `.claude/settings.local.json`) blocks any agent commit whose subject doesn't match; and the squash-merge setting makes the validated PR title the commit of record. release-please's own Release PRs (branch `release-please--*`, titled `chore(repo): release …`) are already compliant and additionally skipped by the lint as a safety net.

## Releases (release-please)

`release-please.yml` watches `main`, parses these commits, and maintains **one batched Release PR** (`release-please-config.json` + `.release-please-manifest.json`); merging it bumps each changed component's version + `CHANGELOG.md` and publishes the tag(s) — `vX.Y.Z` for `infra` (which writes `infra/VERSION`), `<component>-v0.x` for the `0.x` config tracks (`cloud`, `mcp-connector`, the services). **The runtime deploys are release-gated off those tags:** the `infra` release fires `deploy-infra.yml`, a service release fires `deploy-services.yml` (`cloud/` Terraform stays apply-on-merge via `apply-cloud.yml`). So merging a feature PR *stages* a change; merging the Release PR *ships* it. release-please authenticates via a **GitHub App** (`RELEASE_PLEASE_APP_ID` + `RELEASE_PLEASE_APP_PRIVATE_KEY`) so its Release PR triggers the required `gate` check — and so the published `release` events trigger the deploy workflows.

**Full flow, components, versioning policy, and required GitHub config: [docs/releases.md](docs/releases.md).** Never hand-edit `.release-please-manifest.json`, `infra/VERSION`, or any generated `CHANGELOG.md`.

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