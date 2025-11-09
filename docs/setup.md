# Deployment

Deploy RP5 Home Server stacks via Docker Swarm and Portainer's remote repository feature.

## Deployment Order

> ⚠️ **Critical**: Infrastructure stack first, then services.

### 1. Infrastructure Stack

Setup secrets and configuration files on your RP5.

- Generate SSL certificates on local machine (not on Pi):

```bash
cd infra/nginx
./generate-ssl.sh
```

- Create secrets directory structure:

```bash
mkdir -p ./infra/secrets
```

- Create secret files:

```bash
# SSL certificates
cp ./infra/nginx/ssl/cert.pem ./infra/secrets/cert.pem
cp ./infra/nginx/ssl/key.pem ./infra/secrets/key.pem

# Cloudflare tunnel token
echo "your_cloudflare_tunnel_token" > ./infra/secrets/cloudflared_token.txt

# Service passwords and tokens (generate secure passwords)
echo "your_backrest_admin_password" > ./infra/secrets/backrest_admin_password.txt
echo "your_portainer_api_key" > ./infra/secrets/portainer_api_key.txt
echo "your_firefly_api_token" > ./infra/secrets/firefly_api_token.txt
echo "your_adguard_password" > ./infra/secrets/adguard_password.txt
echo "yourdomain.com" > ./infra/secrets/domain.txt

# GCP service account for backups (optional)
cp /path/to/your/gcp_service_account.json ./infra/secrets/gcp_service_account.json
```

- Optionally configure Netdata Cloud integration:

```bash
cp ./infra/.env.example ./infra/.env
# Edit .env to add NETDATA_CLAIM_TOKEN if desired
```

- Copy necessary files to RP5 via SCP with SSH:

```bash
# Create directory structure
ssh pi@pi.local "mkdir -p ~/rp5-homeserver/infra/{nginx,secrets,homepage}"

# Copy core infrastructure files
scp ./infra/docker-compose.yml pi@pi.local:~/rp5-homeserver/infra/
scp ./infra/VERSION pi@pi.local:~/rp5-homeserver/infra/

# Copy secrets directory
scp -r ./infra/secrets/ pi@pi.local:~/rp5-homeserver/infra/

# Copy nginx configuration
scp ./infra/nginx/nginx.conf pi@pi.local:~/rp5-homeserver/infra/nginx/
scp -r ./infra/nginx/snippets/ pi@pi.local:~/rp5-homeserver/infra/nginx/

# Copy homepage configuration
scp -r ./infra/homepage/ pi@pi.local:~/rp5-homeserver/infra/

# Copy optional .env file if using Netdata Cloud
# scp ./infra/.env pi@pi.local:~/rp5-homeserver/infra/
  ```

- Initialize Docker Swarm and deploy the infrastructure stack:

```bash
# Initialize Docker Swarm (single-node cluster)
ssh pi@pi.local "docker swarm init"

# Deploy the infrastructure stack using Docker Swarm
ssh pi@pi.local "cd ~/rp5-homeserver/infra && docker stack deploy -c docker-compose.yml infra"
```

> **Note**: Docker Swarm provides better orchestration, health monitoring, and rolling updates compared to Docker Compose. All services are deployed as part of a managed stack with automatic restart policies.

Alternatively, use the automated sync script:

```bash
# Using the sync script (recommended)
PI_SSH_USER=pi ./scripts/sync_infra.sh --pull
```

Update hostname resolution on your **local machine** (not on Pi):

```bash
# Then add to your local machine /etc/hosts
sudo vim /etc/hosts
# Add (replace with your Pi's actual IP):
# 192.168.x.x portainer.home netdata.home backrest.home <other_service>.home
```

Now you can access Portainer at `https://portainer.home` and control all services (stacks) via the web UI.

See [infra README](../infra/README.md) for details.

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
- Go to **Stacks** > **Add stack** > **From repository**
- **Important**: Select "Swarm" as the deploy mode
- Select the service stack (e.g. `services/n8n/docker-compose.yml`)
- Click **Deploy the stack**

See [How to add a service](./services.md) for details.