# Deployment

Deploy RP5 Home Server stacks via Docker Swarm and Portainer's remote repository feature.

## Deployment Order

> ⚠️ **Critical**: Infrastructure stack first, then services.

### 1. Infrastructure Stack

#### Prerequisites

1. **Deploy cloud infrastructure** (recommended):
   - Cloudflare tunnel for external access
   - GCS bucket for backups
   - See [Cloud](./cloud.md) for Terraform setup

2. **Create secrets** in `infra/secrets/`:
   - SSL certificate and key (`cert.pem`, `key.pem`)
   - Cloudflare tunnel token
   - Service passwords (backrest, adguard, grafana)
   - API tokens (portainer, firefly—after deployment)
   - GCP service account for backups

   See [`infra/README.md`](../infra/README.md) for complete secret requirements.

2. **Initialize Docker Swarm** (first time only):
   ```bash
   ssh pi@pi.local "docker swarm init"
   ```

3. **Create external networks**:
   ```bash
   ssh pi@pi.local "docker network create --driver overlay --attachable rp5_public"
   ssh pi@pi.local "docker network create --driver overlay --attachable rp5_infra"
   ```

#### Deploy

Use the sync script:
```bash
./scripts/sync_infra.sh
```

This syncs `infra/` to the Pi and runs `docker stack deploy`. See [`scripts/README.md`](../scripts/README.md) for options.

Configure DNS resolution for `.home` domains via AdGuard DNS rewrites. See [Networking](./networking.md#dns-resolution).

Access Portainer at `https://portainer.home` to manage all stacks.

### 2. Deploy service stacks

Each `services/<stack>` is a Portainer Remote Stack (Swarm mode, **Webhook**
GitOps updates). Deploys are release-gated: `deploy-services.yml` fires the
stack's webhook from the Pi runner when its `<stack>-v*` release is published.

1. Create the stack's external secrets: `PI_SSH_USER=<user> ./scripts/create_secrets.sh <stack>`
2. Create the Remote Stack and webhook: [GitOps → Per-stack Portainer setup](./gitops.md#per-stack-portainer-setup-once-per-stack)
3. Set the `WEBHOOK_ID_<STACK>` repo secret: [GitOps → GitHub config](./gitops.md#github-config)

New stacks: [GitOps → Adding a new service stack](./gitops.md#adding-a-new-service-stack).
