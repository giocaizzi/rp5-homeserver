# Deployment

Deploy RP5 Home Server stacks via Portainer's remote repository feature.

## Deployment Order

> ⚠️ **Critical**: Infrastructure stack first, then services.

### 1. Infrastructure Stack

Copy base stack files and env variables to your RP5.

```bash
scp ./infra/docker-compose.yml pi@<rp5-ip>:~/rp5-homeserver/docker-compose.yml
scp .env.example pi@<rp5-ip>:~/rp5-homeserver/.env
```

SSH to your RP5 and edit `.env`.

```bash
ssh pi@<rp5-ip>
cd ~/rp5-homeserver
# Edit .env to add variables
```

Depploy the infrastructure stack with Docker compose.
```bash
docker-compose up -d
```

Now you can access Portainer at `https://portainer.local` and control all services (stacks) via the web UI.

See [infra README](../infra/README.md) for details.

### 2. Deploy service stacks

Add Remote Repository in Portainer:
- URL: `https://github.com/giocaizzi/rp5-homeserver`
- Branch: `refs/heads/main`
- Authentication: Configure if private repo

#### Deploy with Portainer

See [How to add a service](./services.md).

Once added to the repository, deploy each service stack via Portainer:
- Go to **Stacks** > **Add stack** > **From repository**
- Select the service stack (e.g. `services/n8n/docker-compose.yml`)
- Click **Deploy the stack**

#### Deploy manually with Docker CLI

SSH to your RP5 and deploy each service stack:
```bash
cd ~/rp5-homeserver/services/<service-name>
docker-compose up -d
```
