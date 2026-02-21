# 🦞 OpenClaw — Personal AI assistant gateway

OpenClaw gateway deployed as a Swarm service. Connects to messaging channels (Telegram, Discord,
WhatsApp, etc.) and serves the Control UI at `openclaw.home`.

---

## 🚀 Quick Start

**1. Generate and store the gateway token:**

```sh
openssl rand -hex 32 > services/openclaw/secrets/gateway_token.txt
```

**2. Create the Swarm secret on the Pi:**

```sh
ssh pi@pi.local "docker secret create openclaw_gateway_token -" < services/openclaw/secrets/gateway_token.txt
```

**2. Deploy via Portainer** (Remote Stack → this repo → `services/openclaw`).

**3. Run onboarding** (interactive — required before channels work):

```sh
PI_SSH_USER=pi ./services/openclaw/openclaw.sh onboard
```

When prompted:
- Gateway bind: `lan` (already configured)
- Gateway auth: `token` (already configured)
- Tailscale: `off`
- Install daemon: `no`

**4. Open Control UI:** `https://openclaw.home`

Paste the token when prompted (Settings → token). It's stored locally at `services/openclaw/secrets/gateway_token.txt`.

---

## 📦 Architecture

| Service   | Image                                    | Port  | Role    |
|-----------|------------------------------------------|-------|---------|
| `gateway` | `ghcr.io/openclaw/openclaw:2026.2.19`   | 18789 | Gateway + Control UI |

**Security model:**
- Runs directly as `node` (uid 1000) — never as root. `entrypoint.sh` only injects the Swarm secret before `exec`.
- Named volumes are initialised with correct ownership by Docker (image already owns `/home/node` as uid 1000).
- No host bind mounts, no privileged mode, no Docker socket access.
- `no-new-privileges` security option enforced.

> If deploying over a pre-existing volume created with wrong ownership, fix it once:
> `ssh pi@pi.local 'docker run --rm -v openclaw_config_data:/data alpine chown -R 1000:1000 /data'`

---

## 🔐 Secrets

| Secret                    | Description                  | 
|---------------------------|------------------------------|
| `openclaw_gateway_token`  | Gateway auth token (hex-32)  |

---

## ⚙️ Configuration

Config persists in `config_data` volume at `/home/node/.openclaw/openclaw.json`.

### CLI — `openclaw.sh`

Runs any openclaw command on the Pi gateway container from your local machine:

```sh
PI_SSH_USER=pi ./services/openclaw/openclaw.sh <command> [args...]
```

Tip: set `PI_SSH_USER` in your shell profile to drop it from every call:
```sh
export PI_SSH_USER=pi
```

### Common commands

```sh
./services/openclaw/openclaw.sh doctor
./services/openclaw/openclaw.sh health
./services/openclaw/openclaw.sh gateway status
./services/openclaw/openclaw.sh channels list
./services/openclaw/openclaw.sh devices list
./services/openclaw/openclaw.sh pairing approve telegram <code>
```

### Add a channel

```sh
# Telegram
./services/openclaw/openclaw.sh channels add --channel telegram --token "<bot-token>"

# Discord
./services/openclaw/openclaw.sh channels add --channel discord --token "<bot-token>"

# WhatsApp (interactive QR — TTY allocated automatically)
./services/openclaw/openclaw.sh channels login
```

---

## 💾 Volumes

| Volume           | Mount path                        | Contents                   |
|------------------|-----------------------------------|----------------------------|
| `config_data`    | `/home/node/.openclaw`            | Config, credentials, state |
| `workspace_data` | `/home/node/.openclaw/workspace`  | Agent workspace, skills    |
