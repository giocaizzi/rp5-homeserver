# GitOps

End-to-end deployment driven by GitHub Actions + GitHub Environments. Every
layer deploys from `main` with an audit trail (Deployments tab) and an optional
human approval gate (env "Required reviewers"), mirroring the `cloud/` pipeline.

## Deployment Methods

| Layer | Trigger | Engine | Environment |
|-------|---------|--------|-------------|
| `cloud/` | push to `main` (`cloud/**`) | GH Actions + Terraform (WIF) | `cloud-production` |
| `infra/` | push to `main` (`infra/**`) | GH Actions on **self-hosted runner** (Pi) → `sync_infra.sh --local` | `pi-production` |
| `services/` | push to `main` (`services/**`) | GH Actions (Pi runner) → local Portainer GitOps webhook | `pi-services` |

```
Edit locally → PR → merge to main
   ├─ cloud/**     → cd.yml             → terraform apply           (cloud-production)
   ├─ infra/**     → deploy-infra.yml   → runner on Pi: stack deploy (pi-production)
   └─ services/**  → deploy-services.yml→ POST Portainer webhook(s)  (pi-services)
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
   outside collaborators"** on. `deploy-infra.yml` triggers only on push to
   `main` and `workflow_dispatch` — never on `pull_request` — so untrusted fork
   code never runs on the Pi.

### Manual deploy / options

```bash
# From the Actions tab: "Deploy infra" → Run workflow (pull / restart toggles)
# Or still locally over SSH from your workstation:
PI_SSH_USER=<user> ./scripts/sync_infra.sh            # in-place update
PI_SSH_USER=<user> ./scripts/sync_infra.sh --pull     # pull images first
```

> Bump `infra/VERSION` only when configs/topology change — a changed VERSION
> forces `docker stack rm infra` + redeploy (Swarm configs are immutable).

---

## services/ — Portainer webhook from GitHub Actions

`deploy-services.yml` detects which `services/<stack>/` changed in the push, then
the `deploy` job runs on the **Pi self-hosted runner** and POSTs that stack's
**Portainer GitOps webhook** locally (resolving the Portainer host to loopback,
so the request hits nginx → Portainer without leaving the Pi). Portainer then
git-pulls and redeploys only the changed stack(s).

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

> The CF Access service token (`CF_ACCESS_CLIENT_ID/SECRET`) is **no longer used**
> by this workflow — the call is local. Those secrets remain for other uses.

Environment `pi-services` (Settings → Environments): create it; optional
required reviewers.

> Polling fallback: instead of webhooks you can set Portainer's stack to **Git
> polling** (it pulls on an interval). The Actions webhook is preferred — it's
> immediate, mirrors the other layers, and shows in the Deployments tab.

### Adding a new service stack

1. Create `services/<stack>/` and deploy it once in Portainer (steps above).
2. Add `WEBHOOK_ID_<STACK>` repo secret.
3. Add `WEBHOOK_ID_<STACK>: ${{ secrets.WEBHOOK_ID_<STACK> }}` to the `deploy`
   job env in `deploy-services.yml`.

---

## Manual trigger (debug)

```bash
# Re-fire a stack's Portainer webhook directly (through the tunnel)
curl -X POST \
  -H "CF-Access-Client-Id: $CF_ID" \
  -H "CF-Access-Client-Secret: $CF_SECRET" \
  "https://portainer.<zone>/api/stacks/webhooks/<webhook-id>"
```
