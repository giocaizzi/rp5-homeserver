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

2. **Create the infra secrets** in the Secrets Manager project `rp5-homeserver` (key `infra_<file stem>`, e.g. `infra_cert` for `cert.pem`); `sync_infra.sh` writes them to `infra/secrets/` on the Pi:
   - SSL certificate and key (`cert.pem`, `key.pem`)
   - Cloudflare tunnel token
   - Service passwords (backrest, adguard, grafana)
   - API tokens (portainer, firefly—after deployment)
   - GCP service account for backups
   - Docker Hub login for Shepherd (`infra_shepherd_registries`, one line `<id>,docker.io,<user>,<access token>`; read-only token): without it Shepherd's pulls hit the anonymous rate limit

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
PI_SSH_USER=pi DOMAIN=<domain> ./scripts/sync_infra.sh
```

This syncs `infra/` to the Pi and runs `docker stack deploy`. See [`scripts/README.md`](../scripts/README.md) for options.

Configure DNS resolution for `.home` domains via AdGuard DNS rewrites. See [Networking](./networking.md#dns-resolution).

Access Portainer at `https://portainer.home` to manage all stacks.

### 2. Deploy service stacks

Each `services/<stack>` is a Portainer Remote Stack (Swarm mode, **Webhook**
GitOps updates). Deploys are release-gated: `deploy-services.yml` fires the
stack's webhook from the Pi runner when its `<stack>-v*` release is published.

1. Create the stack's external secrets from Secrets Manager: `BWS_ACCESS_TOKEN=<token> PI_SSH_USER=<user> ./scripts/create_secrets.sh <stack>`
2. Create the Remote Stack and webhook: [GitOps → Per-stack Portainer setup](./gitops.md#per-stack-portainer-setup-once-per-stack)
3. Set the `WEBHOOK_ID_<STACK>` secret on environment `pi-services`: [GitOps → GitHub config](./gitops.md#github-config)

New stacks: [GitOps → Adding a new service stack](./gitops.md#adding-a-new-service-stack).

## NVMe health (SMART)

Netdata runs in Swarm and cannot read `/dev/nvme0`, so SMART health is checked on the host: `smartmontools` is installed and `smartd` runs as a systemd service. `scripts/smartd_ntfy.sh` is its `-M exec` hook and posts alerts to ntfy (priority high).

1. Install the hook (from a repo checkout): `sudo install -m 755 scripts/smartd_ntfy.sh /usr/local/bin/smartd_ntfy.sh`
2. Create `/etc/smartd_ntfy.env` (root, mode 600):
   ```
   NTFY_URL=https://ntfy.<domain>
   NTFY_TOPIC=<topic>
   NTFY_TOKEN_FILE=/etc/smartd_ntfy.token
   ```
3. Create `/etc/smartd_ntfy.token` (root, mode 600) holding an ntfy access token allowed to publish to the topic. Take it from Secrets Manager (project `rp5-homeserver`, the ntfy publisher token item); never paste it into chat or commit it.
4. In `/etc/smartd.conf`, replace the stock `DEVICESCAN ...` line with an explicit device line. `<nomailer>` is the literal smartd keyword for "no mail address", valid with `-M exec`. The trailing `-M test` fires one test notification at startup:
   ```
   /dev/nvme0 -d nvme -a -s (S/../.././02|L/../../7/03) -m <nomailer> -M exec /usr/local/bin/smartd_ntfy.sh -M test
   ```
   (Short self-test daily 02:00, long self-test Sundays 03:00.)
5. `sudo systemctl restart smartmontools`, then check `journalctl -u smartmontools` and that the ntfy message arrived. A hook failure is logged there.
6. Remove `-M test` from the line and restart again.

`smartd` polls every 30 minutes by default (`-i 1800` in `smartd_opts` of `/etc/default/smartmontools`).

## Host patching

Security updates from Debian install automatically (`unattended-upgrades`, no auto-reboot); kernel, Docker and vendor packages are manual: [RUNBOOKS/patch-pi-host.md](./RUNBOOKS/patch-pi-host.md).
