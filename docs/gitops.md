# GitOps

End-to-end deployment driven by GitHub Actions + GitHub Environments, with an
audit trail (Deployments tab) and an optional human approval gate (env "Required
reviewers"). The **runtime layers (`infra/`, `services/`) are release-gated** —
they deploy when release-please publishes the component's tag, not on every merge.
`cloud/` Terraform stays apply-on-merge. The release/versioning flow itself lives
in [Releases](./releases.md); this page covers deploy **setup**.

## Deployment Methods

| Layer | Trigger | Engine | Environment |
|-------|---------|--------|-------------|
| `cloud/` | push to `main` (`cloud/**`) | GH Actions + Terraform (WIF) | `cloud-production` |
| `infra/` | **`infra` release** (`v*`) | GH Actions on **self-hosted runner** (Pi) → `sync_infra.sh --local` | `pi-production` |
| `services/` | **service release** (`<stack>-v*`) | GH Actions (Pi runner) → local Portainer GitOps webhook | `pi-services` |

```
Edit locally → PR → merge to main → release-please Release PR → merge
   ├─ cloud/**       → apply-cloud.yml    → terraform apply              (cloud-production)
   │                    (applies on the cloud/** merge — not release-gated)
   ├─ infra release  → deploy-infra.yml   → runner on Pi: stack deploy   (pi-production)
   └─ service release→ deploy-services.yml→ POST that stack's webhook     (pi-services)
```

---

## infra/ — self-hosted runner

`infra/` holds Portainer, cloudflared, nginx, backrest… and its secrets are
file-based and **gitignored** (they live only on the Pi). A cloud runner can't
reach the Pi's Docker socket or those files, so deploys run on a self-hosted
runner installed on the Pi itself.

`deploy-infra.yml` checks out the repo and runs `sync_infra.sh --local`, which
rsyncs `infra/` into the deploy path and runs `docker stack deploy` — no SSH
hop. In `--local` mode the script **excludes `secrets/` from the rsync** so the
`--delete` flag never wipes the on-Pi secrets that aren't in git.

### One-time setup

1. **Install the runner on the Pi** (as the user that owns
   `/home/<user>/rp5-homeserver/infra` and is in the `docker` group):
   ```bash
   # On GitHub: Settings → Actions → Runners → New self-hosted runner → copy the token
   GITHUB_REPO=giocaizzi/rp5-homeserver RUNNER_TOKEN=<token> \
     ./scripts/setup_pi_runner.sh
   ```
   This registers a runner with the `rp5` label and installs it as a systemd
   service. Verify it shows **Idle** under Settings → Actions → Runners.

2. **Repo variable** (Settings → Variables → Actions):
   - `PI_DEPLOY_USER` — the Pi user owning the deploy path (e.g. the runner user)
   - `PI_INFRA_PATH` — *optional* override; default `/home/<PI_DEPLOY_USER>/rp5-homeserver/infra`

3. **Environment** `pi-production` (Settings → Environments): create it; toggle
   **Required reviewers** if you want a manual gate before each deploy.

4. **Security** (Settings → Actions → General): keep **"Require approval for all
   outside collaborators"** on. `deploy-infra.yml` triggers only on a published
   `release` and `workflow_dispatch` — never on `pull_request` — so untrusted fork
   code never runs on the Pi.

### Manual deploy / options

```bash
# From the Actions tab: "Deploy infra" → Run workflow (pull / restart toggles)
# Or still locally over SSH from your workstation:
PI_SSH_USER=<user> ./scripts/sync_infra.sh            # in-place update
PI_SSH_USER=<user> ./scripts/sync_infra.sh --pull     # pull images first
```

> `infra/VERSION` is **release-please-managed** — don't hand-edit it. It bumps
> when the `infra` release is cut (a `feat`/`fix`/`refactor`/`perf` scoped to
> `infra/**`), which fires the in-place deploy. Changed files under
> `infra/nginx/` (bind-mounted) are applied with `nginx -t` + `nginx -s reload`.
> Use `chore(infra):`/`docs(infra):` to change `infra/**` without a version bump
> (and so without a deploy). See [Releases](./releases.md).

---

## services/ — Portainer webhook from GitHub Actions

`deploy-services.yml` fires on a published **service release** (`<stack>-v*`),
parses the stack name from the tag, then the `deploy` job runs on the **Pi
self-hosted runner** and POSTs that stack's **Portainer GitOps webhook** locally
(resolving the Portainer host to loopback, so the request hits nginx → Portainer
without leaving the Pi). Portainer then git-pulls and redeploys that stack.
Non-service releases (`infra`, `cloud`, `mcp-connector`) no-op.

> Why local, not through Cloudflare: Cloudflare's WAF blocks GitHub's cloud
> egress IPs with HTTP 403, so a `ubuntu-latest` runner cannot reach the webhook
> even with a valid CF Access service token. Running on the Pi runner sidesteps
> Cloudflare entirely. The GitOps webhook endpoint is unauthenticated and only
> LAN-reachable from there.

### Per-stack Portainer setup (once per stack)

1. **Portainer** → Stacks → Add Stack → Git Repository
   - **URL**: `https://github.com/giocaizzi/rp5-homeserver`
   - **Branch**: `refs/heads/main`
   - **Compose path**: `services/<stack>/docker-compose.yml`
   - **Mode**: Swarm
   - **Relative path volumes**: enable, base path `/mnt/`
2. Enable **GitOps updates** → **Webhook**, copy the webhook URL. The id is the
   last path segment: `…/api/stacks/webhooks/<WEBHOOK_ID>`.
3. Pre-create the stack's external Swarm secrets:
   `PI_SSH_USER=<user> ./scripts/create_secrets.sh <stack>`

### GitHub config

Repo **secrets**:
- `PORTAINER_URL` — e.g. `https://portainer.giocaizzi.xyz` (host is resolved to
  loopback on the Pi runner; only the hostname is used, for nginx server_name).
- `WEBHOOK_ID_<STACK>` — the webhook id per stack
  (`WEBHOOK_ID_N8N`, `WEBHOOK_ID_FIREFLY`, `WEBHOOK_ID_ADGUARD`, …)

> **On-demand stacks** (`ai`, `code`, `langfuse`, `openclaw`) are started/stopped
> manually and have **no** `WEBHOOK_ID_<STACK>` secret. Their releases are
> expected to log `No webhook secret … — skipping` and exit green without
> redeploying; redeploy them from Portainer when started. To make one
> auto-deploy, create its Portainer webhook and set the secret.

Each service stack's GitOps auto-update must be set to **Webhook** (not Polling)
in Portainer, so the Actions workflow is the single deploy trigger (no polling,
no overlap). The old CF Access service-token webhook path (and its
`github-webhooks` token / `webhook_bypass` policy) has been removed — the call
is local from the Pi runner.

Environment `pi-services` (Settings → Environments): create it; optional
required reviewers.

> Polling fallback: instead of webhooks you can set Portainer's stack to **Git
> polling** (it pulls on an interval). The Actions webhook is preferred — it's
> immediate, mirrors the other layers, and shows in the Deployments tab.

### Adding a new service stack

1. **Stack files** — create `services/<stack>/` with `docker-compose.yml`
   (anchors, labels, `deploy.labels.com.giocaizzi.tier` per
   [Docker Compose Standardization](../AGENTS.md#docker-compose-standardization)
   and [Naming & Labels](./naming_labels.md)), a `secrets/` template if needed,
   and a `README.md` with the required sections
   ([Documentation](../AGENTS.md#documentation)). Validate:
   `docker compose -f services/<stack>/docker-compose.yml config -q`.
2. **Release-please package** — add `"services/<stack>": { "release-type": "simple", "component": "<stack>" }`
   to `release-please-config.json` and `"services/<stack>": "0.1.0"` to
   `.release-please-manifest.json` (seed only; never edit it afterwards). If
   the stack bind-mounts repo files, also add `"extra-files": ["docker-compose.yml"]`
   and `com.giocaizzi.config-rev: "0.1.0" # x-release-please-version` to
   `x-labels-base`, so each release rolls the tasks onto the fresh Portainer
   clone (see the Portainer re-clone trap in [AGENTS.md](../AGENTS.md#deployment)).
3. **Secrets** — `PI_SSH_USER=<user> ./scripts/create_secrets.sh <stack>`.
4. **Portainer** — create the Remote Stack with a **Webhook** GitOps update
   ([Per-stack Portainer setup](#per-stack-portainer-setup-once-per-stack)).
5. **Deploy wiring** — add the `WEBHOOK_ID_<STACK>` repo secret and
   `WEBHOOK_ID_<STACK>: ${{ secrets.WEBHOOK_ID_<STACK> }}` to the `deploy` job
   env in `deploy-services.yml` (`-` in the stack name becomes `_`). Skip for
   on-demand stacks.
6. **Routing** (if nginx-proxied) — attach the service to `rp5_public`, then
   follow the [nginx guide](../infra/nginx/README.md#-adding-a-new-service).
   For public access, also follow the Cloudflare/Terraform recipe
   ("Adding a public service" in [AGENTS.md](../AGENTS.md#cicd)).
7. **Dashboard** — add the tile to `infra/homepage/services.yaml` under a group
   that has a matching `layout:` entry in `infra/homepage/settings.yaml`
   ([Homepage](../AGENTS.md#homepage-dashboard)).
8. **Docs** — add the stack to the service tables in the root
   [README](../README.md) and [docs/README](./README.md).

Land the stack as `feat(<stack>): …`; merging the Release PR then cuts
`<stack>-v0.x` and fires the webhook. Steps 6–7 touch `infra/**` — ship them
as a separate `feat(infra):`/`fix(infra):` PR and cut the `infra` release.

---

## Manual trigger (debug)

```bash
# Re-fire a stack's Portainer webhook from the Pi (same path as the workflow)
ssh pi@pi.local 'curl -sk --resolve portainer.<zone>:443:127.0.0.1 -X POST \
  "https://portainer.<zone>/api/stacks/webhooks/<webhook-id>"'
```
Or run **Deploy services** from the Actions tab with a single `stack` input.
