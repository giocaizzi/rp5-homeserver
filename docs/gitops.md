# GitOps

Automated deployment using Portainer GitOps and GitHub webhooks.

## Deployment Methods

| Component | Method | Trigger |
|-----------|--------|---------|
| `infra/` | `./scripts/sync_infra.sh` | Manual |
| `services/` | Portainer GitOps | Webhook on push |

## Infrastructure Deployment

```bash
# Sync and deploy infra stack
./scripts/sync_infra.sh
```

Script syncs `infra/` to Pi and runs `docker stack deploy`.

## Service Deployment (GitOps)

### Initial Setup

1. **Portainer** → Stacks → Add Stack → Git Repository
2. Configure:
   - **URL**: `https://github.com/<owner>/rp5-homeserver`
   - **Branch**: `refs/heads/main`
   - **Compose path**: `services/<service>/docker-compose.yml`
   - **Mode**: Swarm (not Standalone)
3. Enable **Relative path volumes**:
   - Path: `/mnt/` - (Portainer will create `/mnt/stacks/<service>` and handle uniqueness of directories)
4. Enable **GitOps updates** → Webhook
5. Copy webhook URL

### GitHub Webhook

1. Repository Settings → Webhooks → Add
2. **Payload URL**: Portainer webhook URL
3. **Content type**: `application/json`
4. **Events**: Push events

### Cloudflare Access (External Access)

For webhooks through Cloudflare tunnel, use GitHub Actions with service token authentication.

```yaml
# .github/workflows/deploy.yml
- name: Trigger deployment
  run: |
    curl -X POST \
      -H "CF-Access-Client-Id: ${{ secrets.CF_ACCESS_CLIENT_ID }}" \
      -H "CF-Access-Client-Secret: ${{ secrets.CF_ACCESS_CLIENT_SECRET }}" \
      "${{ secrets.PORTAINER_URL }}/api/stacks/webhooks/${{ secrets.WEBHOOK_ID }}"
```

**Secrets required**:
- `CF_ACCESS_CLIENT_ID` — from `terraform output`
- `CF_ACCESS_CLIENT_SECRET` — from `terraform output`
- `PORTAINER_URL` — `https://portainer.yourdomain.com`
- `WEBHOOK_ID_<SERVICE>` — from Portainer stack GitOps settings

### Stack Paths

| Stack | Compose Path | Webhook Path |
|-------|--------------|--------------|
| n8n | `services/n8n/docker-compose.yml` | `/mnt/stacks/n8n` |
| firefly | `services/firefly/docker-compose.yml` | `/mnt/stacks/firefly` |
| adguard | `services/adguard/docker-compose.yml` | `/mnt/stacks/adguard` |
| ollama | `services/ollama/docker-compose.yml` | `/mnt/stacks/ollama` |
| langfuse | `services/langfuse/docker-compose.yml` | `/mnt/stacks/langfuse` |
| ntfy | `services/ntfy/docker-compose.yml` | `/mnt/stacks/ntfy` |
| observability | `services/observability/docker-compose.yml` | `/mnt/stacks/observability` |

## Workflow

```
Edit locally → Push to main → GitHub webhook → Portainer pulls → Stack redeploy
```

## Manual Trigger

```bash
# Test webhook
curl -X POST "https://portainer.home/api/stacks/webhooks/<webhook-id>"
```
