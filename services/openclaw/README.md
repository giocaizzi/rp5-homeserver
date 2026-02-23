# 🦞 OpenClaw — Personal AI assistant gateway

OpenClaw gateway deployed as a Swarm service. Connects to messaging channels (Telegram, Discord,
WhatsApp, etc.) and serves the Control UI at `openclaw.giocaizzi.xyz`.

---

## 🚀 Quick Start

**1. Deploy via Portainer** (Remote Stack → this repo → `services/openclaw`).

**2. Run onboarding** (interactive — required before channels work):

```sh
PI_SSH_USER=pi ./services/openclaw/openclaw.sh onboard
```

When prompted:
- Gateway bind: `lan` (already configured)
- Gateway auth: `token` (set your token in onboarding)
- Tailscale: `off`
- Install daemon: `no`

**3. Configure provider auth with CLI token flows:**

```sh
# Anthropic (setup token from `claude setup-token`)
PI_SSH_USER=pi ./services/openclaw/openclaw.sh models auth setup-token

# OpenAI/API token style providers
PI_SSH_USER=pi ./services/openclaw/openclaw.sh models auth paste-token
```

**4. Configure channel tokens with CLI:**

```sh
# Telegram
PI_SSH_USER=pi ./services/openclaw/openclaw.sh channels add --channel telegram --token "<bot-token>"
```

**5. Open Control UI:** `https://openclaw.giocaizzi.xyz`

Use the gateway token configured during onboarding.

---

## 📦 Architecture

| Service   | Image                                    | Port  | Role    |
|-----------|------------------------------------------|-------|---------|
| `gateway` | `ghcr.io/openclaw/openclaw:2026.2.19`   | 18789 | Gateway + Control UI |

**Security model:**
- Runs directly as `node` (uid 1000) — never as root.
- Named volumes are initialised with correct ownership by Docker (image already owns `/home/node` as uid 1000).
- No host bind mounts, no privileged mode, no Docker socket access.
- `no-new-privileges` security option enforced.

> If deploying over a pre-existing volume created with wrong ownership, fix it once:
> `ssh pi@pi.local 'docker run --rm -v openclaw_config_data:/data alpine chown -R 1000:1000 /data'`

---

## 🔐 Secrets

OpenClaw credentials are managed via OpenClaw CLI and persisted in `config_data` volume.

- Gateway auth token: set during `openclaw onboard` / `openclaw configure`.
- Model/provider credentials: `openclaw models auth setup-token|paste-token|login`.
- Channel bot tokens: `openclaw channels add --channel <name> --token <token>`.
- Other integration API keys (e.g. web search/Notion-style keys): `openclaw config set <path> <value>`.

Avoid passing secrets in command arguments when possible; prefer interactive token prompts.
Compatibility note: on this deployment (`2026.2.19`), use plain `config set` syntax; `--strict-json` is not supported for `config set`.
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
./openclaw.sh restart
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
- `restart` — Force restart OpenClaw Swarm service (`openclaw_gateway`)
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
> ./services/openclaw/openclaw.sh restart
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

### Auth verification

```sh
# Verify provider auth profiles
./services/openclaw/openclaw.sh models status --probe

# Verify channel/gateway health
./services/openclaw/openclaw.sh channels status --probe
./services/openclaw/openclaw.sh gateway status
```

### Integration API keys (non-channel)

```sh
# Example: web search API key path
./services/openclaw/openclaw.sh config set tools.web.search.apiKey "<api-key>"

# Inspect current value/path
./services/openclaw/openclaw.sh config get tools.web.search.apiKey
```

### Task-specific agents (recommended)

Use native OpenClaw multi-agent profiles instead of router skills:

- `main` (default): routine tasks with `anthropic/claude-haiku-4-5`
- `complex`: complex tasks with `anthropic/claude-sonnet-4-6`

Both agents keep provider fallback chain.

**Use the right agent per task:**
```bash
# Routine
./openclaw.sh agent --agent main -m "Summarize these notes"

# Complex
./openclaw.sh agent --agent complex -m "Debug this traceback and propose a fix plan"
```


---

## 💾 Volumes

| Volume           | Mount path                        | Contents                   |
|------------------|-----------------------------------|----------------------------|
| `config_data`    | `/home/node/.openclaw`            | Config, credentials, state |
| `workspace_data` | `/home/node/.openclaw/workspace`  | Agent workspace, skills    |
