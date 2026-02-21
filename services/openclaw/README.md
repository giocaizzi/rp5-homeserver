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

| Secret                        | Description                       | Generate |
|-------------------------------|-----------------------------------|---------|
| `openclaw_gateway_token`      | Gateway auth token (hex-32)       | `openssl rand -hex 32` |
| `openclaw_anthropic_api_key`  | Anthropic API key (`sk-ant-...`)  | [console.anthropic.com](https://console.anthropic.com) |
| `openclaw_telegram_bot_token` | Telegram bot token                | `@BotFather` → `/newbot` || `openclaw_notion_api_key`     | Notion integration API key        | [notion.so/my-integrations](https://www.notion.so/my-integrations) |
| `openclaw_brave_api_key`      | Brave Search API key              | [api.search.brave.com](https://api.search.brave.com/app/keys) |

```sh
ssh pi@pi.local "docker secret create openclaw_notion_api_key -" < services/openclaw/secrets/notion_api_key.txt
ssh pi@pi.local "docker secret create openclaw_brave_api_key -" < services/openclaw/secrets/brave_api_key.txt
```
---

## ⚙️ Configuration

Config persists in `config_data` volume at `/home/node/.openclaw/openclaw.json`. The CLI actively modifies this file, so it cannot be mounted from repo like static configs.

### Local editing workflow

```bash
# Download config from Pi
./openclaw.sh pull-config

# Edit locally
vim openclaw.json  # or your preferred editor

# Upload to Pi
./openclaw.sh push-config

# Apply changes (if needed)
ssh pi@pi.local "docker service update --force openclaw_gateway"
```

### Remote editing (vim in container)

```bash
./openclaw.sh edit-config
```

**Prompt caching:** Add under `agents.defaults.models` to reduce latency & costs:
```json
"anthropic/claude-opus-4-6": { "params": { "cacheRetention": "long" } }
```
Options: `"none"`, `"short"` (5min), `"long"` (1hr, 2x cost)

### CLI — `openclaw.sh`

Wrapper for executing OpenClaw commands on the remote Pi gateway container.

```sh
./openclaw.sh <command> [args...]
./openclaw.sh help    # Show all available commands
```

**Special commands:**
- `edit-config` — Edit `openclaw.json` with vim (auto-installs if needed)
- `shell` — Drop into container shell
- `help` — Show usage information

**Examples:**
```sh
./openclaw.sh edit-config
./openclaw.sh doctor
./openclaw.sh channels list
./openclaw.sh devices list
./openclaw.sh pairing approve telegram <code>
```

> **Note:** `gateway restart` is not supported in Docker Swarm — openclaw uses `systemctl --user` internally which is unavailable inside the container. Use the Swarm service update instead:
> ```sh
> ssh pi@pi.local "docker service update --force openclaw_gateway"
> ```

### Add a channel

```sh
# Telegram
./services/openclaw/openclaw.sh channels add --channel telegram --token "<bot-token>"

# Discord
./services/openclaw/openclaw.sh channels add --channel discord --token "<bot-token>"

# WhatsApp (interactive QR — TTY allocated automatically)
./services/openclaw/openclaw.sh channels login
```

### Cost optimization (optional)

Deploy the `router` skill to automatically route queries to cost-appropriate models (Haiku for routine, Sonnet for complex):

```bash
# Upload router skill
cat services/openclaw/skills/router.py | ssh pi@pi.local \
  "docker exec -i \$(docker ps -q -f name=openclaw_gateway) \
  sh -c 'mkdir -p /home/node/.openclaw/workspace/skills && \
  cat > /home/node/.openclaw/workspace/skills/router.py'"

# Enable skill
./openclaw.sh skills enable router --path /home/node/.openclaw/workspace/skills/router.py
```

Reduces API costs by 80-90% by routing routine tasks to Haiku ($0.30/MTok) instead of Sonnet ($3/MTok).

---

## 💾 Volumes

| Volume           | Mount path                        | Contents                   |
|------------------|-----------------------------------|----------------------------|
| `config_data`    | `/home/node/.openclaw`            | Config, credentials, state |
| `workspace_data` | `/home/node/.openclaw/workspace`  | Agent workspace, skills    |
