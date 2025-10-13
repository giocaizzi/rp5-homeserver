# Deployment

Deploy RP5 Home Server stacks via Portainer's remote repository feature.

## Deployment Order

> ⚠️ **Critical**: Infrastructure stack first, then services.

### 1. Infrastructure Stack

Setup necessary files and folders on your RP5.

- Generate SSL certificates on local machine (not on Pi):

```bash
cd infra/nginx
./generate-ssl.sh
```

- Create env file from example:

```bash
cp ./infra/.env.example ./infra/.env
```

- Edit your `.env` file to add necessary variables.

- Copy necessary files to RP5 via SCP with SSH:

```bash
# Create directory structure
ssh pi@pi.local "mkdir -p ~/rp5-homeserver/infra/{nginx/ssl,backup/secrets}"

# Copy core infrastructure files
scp ./infra/docker-compose.yml ./infra/.env pi@pi.local:~/rp5-homeserver/infra/

# Copy nginx configuration and SSL certificates
scp ./infra/nginx/nginx.conf pi@pi.local:~/rp5-homeserver/infra/nginx/
scp ./infra/nginx/ssl/*.pem pi@pi.local:~/rp5-homeserver/infra/nginx/ssl/

# Copy backup scripts (optional)
scp ./infra/backup/{backup.sh,restore.sh} pi@pi.local:~/rp5-homeserver/infra/backup/
```

- **Optional: Setup backup secrets** (see [Backup System](../docs/backup.md)):
  ```bash
  # Create secrets on Pi
  ssh pi@pi.local "echo 'your-strong-restic-password' > ~/rp5-homeserver/infra/backup/secrets/restic_password.txt"
  
  # Copy your GCP service account JSON file to Pi
  scp /path/to/your/gcp_service_account.json pi@pi.local:~/rp5-homeserver/infra/backup/secrets/
  ```

- **Optional: Setup automated backups**:
  ```bash
  ssh pi@pi.local
  sudo crontab -e
  # Add: 0 2 * * * cd /home/pi/rp5-homeserver/infra && ./backup/backup.sh >> /var/log/restic-backup.log 2>&1
  ```

- Start the infrastructure stack with Docker compose:

```bash
ssh pi@pi.local "cd ~/rp5-homeserver/infra && docker-compose up -d"
```

> **Note**: You may see warnings about kernel memory limit capabilities not being supported. This is normal on Raspberry Pi systems where cgroups memory management isn't enabled by default. The containers will still run properly, but memory limits defined in the compose files will be ignored. To enable memory limits, you would need to add `cgroup_enable=memory cgroup_memory=1` to `/boot/firmware/cmdline.txt` and reboot, but this is optional for normal operation.

Update hostname resolution on your **local machine** (not on Pi):

```bash
# Then add to your local machine /etc/hosts
sudo vim /etc/hosts
# Add (replace with your Pi's actual IP):
# 192.168.x.x portainer.local netdata.local <other_service>.local
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