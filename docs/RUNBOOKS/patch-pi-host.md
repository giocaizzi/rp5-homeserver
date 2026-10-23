# Patch the Pi host

**When:** a Debian security advisory or a kernel/Docker CVE is announced, or for the monthly check. Containers are patched separately (Shepherd for `:latest`/floating tags, a rebuild for the Firefly fork).
**Preconditions:** SSH to the Pi (`ssh pi.local`), sudo.

## What is automatic
`unattended-upgrades` installs updates from the **Debian and Debian-Security** origins daily (`/etc/apt/apt.conf.d/20auto-upgrades`) and never reboots. Everything else is manual on purpose:

| Package source | Why manual |
|---|---|
| Raspberry Pi (kernel, firmware) | needs a reboot |
| Docker CE / containerd | restarts the daemon and every Swarm task |
| cloudflared, gh | different vendors; cloudflared restart drops the tunnel briefly |

## Steps
1. **Check what is pending:** `apt list --upgradable 2>/dev/null`; running kernel: `uname -r`.
2. **Back up first:** Backrest → plan `docker-volumes` → Backup now.
3. **Upgrade:** `sudo apt-get update && sudo apt-get full-upgrade`. Docker/containerd upgrades restart all services.
4. **Reboot if the kernel changed** (`ls /var/run/reboot-required`, or `uname -r` differs from the newest `linux-image-*` installed): `sudo reboot`. Expect the whole Swarm to be down for a few minutes.
5. **Verify:** `docker service ls` shows every service at its desired replicas; open `https://<service>.home` for one stack per tier.

## Auto-upgrade checks
- Dry run: `sudo unattended-upgrade --dry-run -d` (lists allowed origins and pending packages).
- History: `/var/log/unattended-upgrades/unattended-upgrades.log`.
- Reinstall: `sudo apt-get install unattended-upgrades` and write `20auto-upgrades` with `APT::Periodic::Update-Package-Lists "1";` and `APT::Periodic::Unattended-Upgrade "1";`.
