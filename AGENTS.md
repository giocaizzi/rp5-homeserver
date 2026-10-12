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
| `infra/` | Always-on infra stack (nginx, portainer, cloudflared, netdata, backrest, homepage, shepherd). Single `docker-compose.yml` + `VERSION`; file-based `secrets/` live only on the Pi, written from Secrets Manager by `sync_infra.sh`. |
| `services/<stack>/` | One folder per service stack (n8n, firefly, adguard, ai, langfuse, ntfy, observability, openclaw, greenhouse, code, crm). Each ships a `docker-compose.yml` and a README; secrets come from Secrets Manager (project `rp5-homeserver`), never from files in the stack folder. |
| `scripts/` | Operational scripts — see Common Commands. |
| `cloud/` | Terraform for Cloudflare Tunnel + GCS backup bucket. |
| `docs/` | Documentation (source of truth): see "Where to find what". |
| `.claude/skills/` | Repo-local agent skills (e.g. `firefly`, `openclaw-cli`). |
| `.github/workflows/` | CI/CD. Workflow list and triggers: [docs/ci_cd.md](docs/ci_cd.md). |

**Branch protection:** commits to `main` are blocked. All changes go through feature branches + PRs. **Every PR title and commit subject MUST be `type(scope): description`** — a Conventional Commit with a mandatory scope (release-please parses it; `main` is squash-only with title = PR title; `pr-title.yml` lints it). Format, scope vocabulary and bump rules: [docs/releases.md](docs/releases.md#pull-requests--commit-titles-mandatory-format). Never hand-edit `.release-please-manifest.json`, `infra/VERSION`, or any generated `CHANGELOG.md`.

---

# Common Commands

All scripts require `PI_SSH_USER`. `PI_HOST` defaults to `pi.local`.

```bash
# Deploy / update the infra stack (rsync infra/ → deploy stack)
PI_SSH_USER=giorgiocaizzi ./scripts/sync_infra.sh
PI_SSH_USER=giorgiocaizzi ./scripts/sync_infra.sh --pull   # pull latest images first

# Sync Swarm external secrets for a service stack from Bitwarden Secrets Manager (project rp5-homeserver; used before first Portainer deploy)
# Needs BWS_ACCESS_TOKEN (machine account with read access), bws and jq.
PI_SSH_USER=giorgiocaizzi ./scripts/create_secrets.sh <stack>             # n8n | firefly | langfuse | observability | ...
PI_SSH_USER=giorgiocaizzi ./scripts/create_secrets.sh --all               # every stack under services/
PI_SSH_USER=giorgiocaizzi ./scripts/create_secrets.sh <stack> --dry-run
PI_SSH_USER=giorgiocaizzi ./scripts/create_secrets.sh <stack> --prune     # delete secrets on Pi not referenced by the compose file

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

There is no application test/lint/build suite — this repo is configuration. "Tests" = `make check` (`docker compose config` + `shellcheck`, also the CI `check` job) + post-deploy health checks via `docker service ps` / service health endpoints (`https://<service>.home`).

---

# Constraints

- Minimal Swarm config: avoid unnecessary stacks, networks, wrappers, CRON containers.
- Never embed secrets in YAML—use Swarm secrets or `.env` files (gitignored).
- Source of truth for `services/` secrets: Bitwarden Secrets Manager project `rp5-homeserver` (key = Swarm secret name). Never keep them as local files. `infra/` secrets stay file-based on the Pi (`file:`) but are generated from the same project (key `infra_<file stem>`, e.g. `infra_cert` for `cert.pem`): `sync_infra.sh` (without `--local`) writes them on the Pi when their hash differs; the Mac and the CI checkout hold no secret files. `*.pem`/`*.json` files end with a newline, the others don't — keep that, or Docker sees a changed (immutable) secret.
- OpenClaw exception: prefer OpenClaw CLI-managed auth (gateway/config/auth profiles/channel tokens) persisted in `config_data` over custom entrypoint secret-export wrappers.
- Use configs only for non-secret, user-level configuration.
- ARM64 compatibility and optimization required for all images.

---

# Security

- Swarm secrets for credentials; `.env` files gitignored.
- Expose ports only when required.
- Internal overlay networks over host networking.
- Non-root containers when possible.
- No `privileged: true`.

---
---

# Where to find what

| Topic | Document |
|-------|----------|
| Compose anchors, service template, Swarm guidelines | [docs/compose_standards.md](docs/compose_standards.md) |
| Naming and labels | [docs/naming_labels.md](docs/naming_labels.md) |
| Deployment mapping, Portainer mounts, re-clone trap, no-symlink rule, `infra/VERSION`, Homepage | [docs/deployment.md](docs/deployment.md) |
| CI/CD workflows, cloud/ auth and variable wiring, adding a public service | [docs/ci_cd.md](docs/ci_cd.md) |
| Releases, versioning, PR/commit title contract | [docs/releases.md](docs/releases.md) |
| GitOps / Portainer webhooks | [docs/gitops.md](docs/gitops.md) |
| Setup, networking, backup, cloud, monitoring | [docs/setup.md](docs/setup.md), [docs/networking.md](docs/networking.md), [docs/backup.md](docs/backup.md), [docs/cloud.md](docs/cloud.md), [docs/monitoring.md](docs/monitoring.md) |
| Documentation and README conventions, file management | [docs/README.md](docs/README.md#documentation-conventions) |
| OpenClaw runbook | `.claude/skills/openclaw-cli/SKILL.md` (auth gateway, channel tokens, `openclaw.sh pull-config` / `push-config`) |
| Firefly runbook | `.claude/skills/firefly/SKILL.md` (not present in this checkout; referenced as before) |

Key gotchas (details in docs/deployment.md): no tracked symlinks in the repo (Portainer rejects them); Tier label must be set in both `labels:` and `deploy.labels:` or Shepherd silently skips the service; Portainer redeploy re-clones the repo, so use `docker service update --force <stack>_<svc>` for out-of-band redeploys; a new `infra/` secret file needs a non-local `sync_infra.sh` run before the infra release.
