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

Deploy services using Portainer's GitOps capabilities with Docker Swarm stacks for automated updates.

#### GitOps Setup (Recommended)

Enable automated deployments with webhook integration using Docker Swarm:

1. **Add Stack from Git Repository:**
   - URL: `https://github.com/giocaizzi/rp5-homeserver`
   - Branch: `refs/heads/main`
   - Compose file: `services/{service}/docker-compose.yml`
   - **Deploy Mode**: Select "Swarm" (not "Standalone")
   - Authentication: Configure if private repo

2. **Enable GitOps Updates:**
   - Toggle **GitOps updates** ON
   - Select **Webhook** mechanism
   - Copy the generated webhook URL

3. **Configure GitHub Webhook:**
   - Repository Settings → Webhooks → Add webhook
   - Payload URL: Use Portainer's webhook URL
   - Events: Push events
   - Content type: `application/json`

4. **Test Workflow:**
   - Make a small change to the service
   - Push to main branch
   - Verify automatic deployment in Portainer

**Benefits:** Automatic updates, version control, audit trail, rollback capabilities, and Docker Swarm orchestration features.

See [GitOps Documentation](./gitops.md) for complete setup guide.

#### Manual Deployment (Alternative)

For services that don't require frequent updates:
1. **Stacks** → **Add stack** → **Git Repository**
2. Configure repository URL and compose path
3. Select **Swarm** deploy mode
4. Deploy