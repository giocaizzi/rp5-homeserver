# GitOps with Portainer

Automated deployment and updates using Portainer's GitOps capabilities with GitHub webhooks behind Cloudflare Access.

## Terraform Configuration Summary

The GitOps webhook setup is fully integrated in `cloud/main.tf`:

### ✅ **What's Configured:**
- **Service Token:** Creates `github-webhooks` token for API access
- **Bypass Policy:** Allows service token to bypass Cloudflare Access
- **Updated Portainer App:** Includes webhook bypass with precedence 1
- **Outputs:** Credentials and setup instructions in `outputs.tf`

### 🚀 **Deployment Steps:**
1. Deploy: `cd cloud && terraform apply`
2. Get credentials: `terraform output -raw github_webhook_client_id` and `terraform output -raw github_webhook_client_secret`
3. Configure GitHub webhook with the credentials (see [Cloudflare Access Integration](#cloudflare-access-integration))
4. Test webhook delivery

---

## Overview

Portainer Business Edition supports GitOps workflows that automatically deploy and update stacks when repository changes are detected. This eliminates manual deployment steps and ensures your services stay synchronized with the repository.

**Key Benefits:**
- Automatic deployment on code changes
- Version-controlled infrastructure
- Centralized configuration management
- Audit trail of all changes
- Rollback capabilities

## GitOps Modes

Portainer supports two GitOps update methods:

### 1. Polling (Automatic Interval)
- Portainer checks the repository periodically
- Configurable interval (default: 5 minutes)
- Good for development/testing
- No external network requirements

### 2. Webhooks (Event-Driven)
- GitHub triggers updates immediately on push
- Near-instant deployments
- Production-recommended
- Requires accessible webhook endpoint

## Architecture

```
GitHub Repository → Webhook → Portainer → Docker Stack Update
     ↓                ↓           ↓              ↓
[Push Event]    [HTTP POST]  [Git Pull]   [Redeploy]
```

**Current Setup:**
- Infrastructure: Manual deployment (SSH)
- Services: GitOps via Portainer stacks
- Webhook endpoint: `https://portainer.local/api/stacks/webhooks/{id}`

## Setup Guide

### 1. Deploy Infrastructure Stack (One-time)

Infrastructure must be deployed manually via SSH as it contains Portainer itself.

```bash
# Sync and deploy infrastructure
rsync -av ./infra/ pi@pi.local:~/rp5-homeserver/infra/
ssh pi@pi.local "cd ~/rp5-homeserver/infra && docker compose up -d"
```

### 2. Configure Service Stacks for GitOps

For each service in the `services/` directory:

1. **Access Portainer** at `https://portainer.local`
2. **Add Stack** → **Git Repository**
3. **Configure Repository:**
   - URL: `https://github.com/giocaizzi/rp5-homeserver`
   - Reference: `refs/heads/main`
   - Compose file: `services/{service}/docker-compose.yml`
   - Authentication: Configure if private repo

4. **Enable GitOps Updates:**
   - Toggle **GitOps updates** ON
   - **Mechanism:** Select "Webhook"
   - **Webhook URL:** Copy the generated URL

5. **Set Environment Variables** (if needed)
6. **Deploy the Stack**

### 3. Configure GitHub Webhooks

For each service stack with GitOps enabled:

1. **Go to GitHub Repository Settings**
2. **Webhooks** → **Add webhook**
3. **Configure Webhook:**
   - **Payload URL:** Use Portainer's webhook URL
   - **Content type:** `application/json`
   - **Events:** Select "Push events"
   - **Active:** ✓ Enabled

**Webhook URL Format:**
```
https://portainer.local/api/stacks/webhooks/{webhook-id}
```

### 4. Test the Workflow

1. **Make a change** to a service's docker-compose.yml
2. **Push to main branch**
3. **Verify:** Check Portainer for automatic stack update
4. **Monitor:** Use stack activity logs to verify deployment

## Service Configuration

### Current Services Setup

| Service | GitOps Status | Path | Notes |
|---------|---------------|------|-------|
| **Infrastructure** | Manual | `infra/` | Contains Portainer itself |
| **N8N** | GitOps Ready | `services/n8n/` | Automation platform |
| **Firefly III** | GitOps Ready | `services/firefly/` | Personal finance |
| **AdGuard Home** | GitOps Ready | `services/adguard/` | DNS filtering |
| **Ollama** | GitOps Ready | `services/ollama/` | Local LLM server |

### Service Requirements

Each service stack needs:
- **Isolated networks** for security
- **Connection to `rp5_public`** for nginx access
- **Environment variables** for sensitive configuration
- **Health checks** for reliable deployments
- **Resource limits** for stability

## Environment Variables

### Stack-Level Variables
Define in Portainer stack configuration:
```bash
# Database credentials
DB_PASSWORD=secure_password_here
POSTGRES_PASSWORD=secure_password_here

# API tokens
FIREFLY_API_TOKEN=your_api_token
N8N_BASIC_AUTH_PASSWORD=secure_password

# Service hostnames
N8N_HOST=n8n.local
FIREFLY_HOST=firefly.local
```

### Dynamic Variables via Webhooks
Pass variables through webhook URL:
```
https://portainer.local/api/stacks/webhooks/{id}?SERVICE_TAG=latest
```

Reference in compose files:
```yaml
services:
  app:
    image: myapp:${SERVICE_TAG:-stable}
```

## Cloudflare Access Integration

### Automatic Service Token Creation

GitHub Actions workflows use Cloudflare Access service tokens for webhook authentication. The service token is automatically created via Terraform. After running `terraform apply` in the cloud directory, get the credentials:

```bash
# Get the webhook credentials
cd cloud
terraform output -raw github_webhook_client_id
terraform output -raw github_webhook_client_secret
```

### GitHub Actions Deployment

Since GitHub webhooks cannot send custom headers, we use **GitHub Actions** to trigger deployments with proper Cloudflare Access authentication.

#### Setup Repository Secrets:
1. Go to repository **Settings** → **Secrets and variables** → **Actions**
2. Add these repository secrets:
   
   **Authentication:**
   - `CF_ACCESS_CLIENT_ID`: Your client ID from terraform output
   - `CF_ACCESS_CLIENT_SECRET`: Your client secret from terraform output
   
   **Configuration:**
   - `PORTAINER_URL`: `https://portainer.yourdomain.com`
   
   **Webhook IDs (get from Portainer GitOps stacks):**
   - `WEBHOOK_ID_N8N`: Your n8n webhook ID
   - `WEBHOOK_ID_FIREFLY`: Your firefly webhook ID  
   - `WEBHOOK_ID_ADGUARD`: Your adguard webhook ID
   - `WEBHOOK_ID_OLLAMA`: Your ollama webhook ID (if used)

#### Automated Deployment Workflow:
The `.github/workflows/deploy.yml` automatically:
- Detects which services changed in `services/` directory
- Triggers deployment for only the changed services
- Uses Cloudflare Access headers for authentication
- Provides deployment status feedback

#### Get Webhook IDs:
For each GitOps-enabled stack in Portainer:
1. Navigate to the stack in Portainer UI
2. Find the **GitOps updates** section
3. Copy the webhook URL
4. Extract the ID from: `https://portainer.yourdomain.com/api/stacks/webhooks/{webhook-id}`
5. Update the `WEBHOOK_URLS` in `.github/workflows/deploy.yml`

### Test Webhook (Manual)

Test individual webhooks manually:

```bash
curl -X POST \
  -H "CF-Access-Client-Id: $(terraform output -raw github_webhook_client_id)" \
  -H "CF-Access-Client-Secret: $(terraform output -raw github_webhook_client_secret)" \
  "https://portainer.yourdomain.com/api/stacks/webhooks/{webhook-id}"
```

## Webhook Configuration

### Security Considerations

**Access Control:**
- Webhook URLs contain unique IDs (not guessable)
- Only GitHub has webhook URLs
- Portainer validates payload source
- HTTPS encryption in transit

**Network Security:**
- Webhooks accessible via nginx proxy
- Rate limiting applied (`general` zone)
- No direct port exposure to internet

### Troubleshooting GitHub Actions Deployment

**Common Issues:**

1. **Action not triggering:**
   - Check if changes are in `services/` directory
   - Verify push is to `main` branch
   - Check GitHub Actions tab for workflow runs

2. **Authentication failures:**
   - Verify repository secrets are set correctly
   - Test webhook manually with `./test-webhooks.sh`
   - Check Cloudflare Access policy allows service token

3. **Webhook not found (404):**
   - Verify webhook ID in `.github/workflows/deploy.yml`
   - Check if Portainer stack has GitOps enabled
   - Confirm webhook URL format is correct

4. **Deployment failures:**
   - Check Portainer stack activity logs
   - Verify Git repository accessibility from Portainer
   - Confirm compose file path is correct

**Monitoring:**
- GitHub Actions workflow logs
- Portainer stack activity
- Nginx access logs (webhook requests)
- Container status in homepage

## Best Practices

### Repository Structure
```
rp5-homeserver/
├── infra/                  # Manual deployment
│   ├── docker-compose.yml
│   └── nginx/
├── services/              # GitOps deployment
│   ├── n8n/
│   │   └── docker-compose.yml
│   ├── firefly/
│   │   └── docker-compose.yml
│   └── {service}/
└── docs/
```

### Development Workflow
1. **Make changes** in feature branch
2. **Test locally** if possible
3. **Create pull request** for review
4. **Merge to main** triggers automatic deployment
5. **Monitor deployment** via Portainer

### Environment Management
- **Development:** Use polling for faster iteration
- **Production:** Use webhooks for immediate updates
- **Staging:** Consider separate branch/environment

### Backup Strategy
- **Infrastructure:** Manual backup before changes
- **Services:** GitOps provides version history
- **Data:** Automated backups via Backrest
- **Configuration:** Environment variables documented

## Migration from Manual Deployment

To migrate existing manually-deployed services to GitOps:

1. **Prepare service** with proper compose file structure
2. **Document environment variables** currently in use
3. **Create Portainer stack** from Git repository
4. **Configure GitOps** with webhook
5. **Test deployment** with minor change
6. **Remove manual deployment** when confirmed working

## Monitoring and Maintenance

### Health Checks
- **Stack status** in Portainer dashboard
- **Service health** via homepage widgets
- **Infrastructure monitoring** via Netdata
- **Backup status** via Backrest

### Regular Tasks
- **Review webhook deliveries** for failed deployments
- **Update service configurations** as needed
- **Monitor resource usage** and adjust limits
- **Backup verification** and rotation

## Advanced Configuration

### Custom Webhook Parameters

**Prevent image pulls:**
```
{webhook_url}?pullimage=false
```

**Specify image tag:**
```
{webhook_url}?tag=v1.2.3
```

**Force redeployment:**
```
curl -X POST {webhook_url}
```

### Multiple Environment Support

Use branch-based deployments:
- `main` → Production environment
- `staging` → Staging environment
- `develop` → Development environment

Configure different webhook URLs for each environment.

### Integration with CI/CD

**GitHub Actions Integration:**
```yaml
- name: Trigger Portainer Deployment
  run: |
    curl -X POST ${{ secrets.PORTAINER_WEBHOOK_URL }}
```

**Conditional Deployment:**
```yaml
if: github.ref == 'refs/heads/main'
```

This GitOps setup provides automated, reliable deployments while maintaining security and observability across your home server infrastructure.