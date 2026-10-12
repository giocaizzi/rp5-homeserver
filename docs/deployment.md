# Deployment Reference

Component → workflow mapping, Portainer Remote Stack mounts, infra versioning and the dashboard. Setup steps: [Setup](./setup.md); triggers: [GitOps](./gitops.md), [Releases](./releases.md).

## Deployment

| Component | Workflow |
|-----------|----------|
| `infra/`  | **`infra` release** (`v*`) → `deploy-infra.yml` (Pi runner, `sync_infra.sh --local`). Manual: `workflow_dispatch`, or `PI_SSH_USER=<user> DOMAIN=<domain> ./scripts/sync_infra.sh` |
| `services/` | **service release** (`<stack>-v*`) → `deploy-services.yml` fires that stack's Portainer webhook |
| `workers/mcp-connector/` | **`mcp-connector` release** (`mcp-connector-v*`) → `deploy-workers.yml` (`wrangler deploy --env`, 7 envs). Manual: `workflow_dispatch`, or `./deploy.sh` (bootstrap/secrets only) |
| `cloud/` | Push `cloud/**` → `apply-cloud.yml` (`terraform apply`, plan-reviewed-on-merge) |

**Portainer Remote Stacks:** Portainer clones repo, enabling relative bind mounts (`./config`), Swarm configs (`file:`), and named volumes. Secrets must be external (pre-created on Pi). The public domain is not in the repo: compose files use `${DOMAIN:?…}`, filled from the stack's Portainer environment variable `DOMAIN` ([GitOps → Per-stack Portainer setup](./gitops.md#per-stack-portainer-setup-once-per-stack)).

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

> **Portainer re-clone trap.** A Portainer redeploy deletes and re-clones the repo; tasks whose spec didn't change keep the old (deleted) bind-mount inode — directories go empty, files stay stale. Stacks with repo bind mounts carry `com.giocaizzi.config-rev: "<ver>" # x-release-please-version` in `x-labels-base`, listed under that package's `extra-files` in `release-please-config.json`, so every release changes the container spec and rolls the tasks. Out-of-band redeploys still need `docker service update --force <stack>_<svc>`.

**`infra/VERSION`** — the infra stack's version, now **owned by release-please** (it is the `infra` package's `version-file`, the bare `vX.Y.Z` main line, seeded at `1.13.0`). **Do not hand-edit it** — release-please overwrites it from `.release-please-manifest.json`. It bumps when an **infra Release PR merges**, i.e. when a releasing-type commit (`feat`/`fix`/`refactor`/`perf`) scoped to `infra/**` lands. It is bind-mounted into homepage (no Swarm config), so a bump alone restarts nothing. `sync_infra.sh` does an in-place `docker stack deploy`; since `infra/nginx/` is bind-mounted, it runs `nginx -t` + `nginx -s reload` in the proxy task whenever nginx file content changed, and force-restarts `infra_monitoring` when a bind-mounted netdata `.conf` changed (spec unchanged ⇒ no restart otherwise). Adding another single-file bind mount to `infra/` means adding it to that list in the script. Deploys are release-gated, so to stage an `infra/**` change *without* cutting an infra release, use a non-releasing type — `chore(infra):` / `docs(infra):`.

---

## Homepage (dashboard)

Two-file pairing in `infra/homepage/`: **sections live in `settings.yaml`** (`layout:` — order, columns, icon), **components reference a section by name in another file** (`services.yaml`, `bookmarks.yaml`). A group used in `services.yaml`/`bookmarks.yaml` **must** have a matching `layout:` entry, or it renders orphaned (no icon, dumped at the end). Adding a service = add the tile under its group **and** ensure that group exists in the layout.
