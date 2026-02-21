---
name: openclaw-cli
description: Repository-specific runbook for operating OpenClaw CLI on the Raspberry Pi Swarm deployment. Use this when asked to inspect, configure, troubleshoot, or operate OpenClaw in this repo.
license: Proprietary (repository internal)
---

# OpenClaw CLI (rp5-homeserver)

Use this skill for any OpenClaw operational task in this repository.

## Authoritative references

- OpenClaw CLI index: https://docs.openclaw.ai/cli
- OpenClaw channels: https://docs.openclaw.ai/cli/channels
- OpenClaw gateway: https://docs.openclaw.ai/cli/gateway
- OpenClaw doctor: https://docs.openclaw.ai/cli/doctor
- OpenClaw skills: https://docs.openclaw.ai/cli/skills

## Repository-specific execution path

1. Prefer the local wrapper script:
   - `./services/openclaw/openclaw.sh <command> [args...]`
2. Run from repository root unless user requests otherwise.
3. If SSH user/host must be overridden, use env vars:
   - `PI_SSH_USER=pi PI_HOST=pi.local ./services/openclaw/openclaw.sh status`
4. Do not run OpenClaw commands directly on macOS host when the task targets the deployed gateway; use the wrapper so gateway URL/context stay consistent.

## Authentication model (critical)

This repository uses OpenClaw CLI-managed auth persisted in OpenClaw state/config.

- Gateway token is configured via `openclaw onboard` / `openclaw configure` (`gateway.auth`).
- Provider credentials are configured via `openclaw models auth ...` profiles.
- Channel bot tokens are configured via `openclaw channels add --token ...`.
- Do not ask users to paste secret values in chat and do not print secret contents in logs/output.

### Which auth path to use

- **Gateway/service auth:** use OpenClaw configuration (`gateway.auth`), managed by onboarding/configure CLI.
- **Provider/model auth (Anthropic/OpenAI/etc):** CLI auth profile flows are valid and often easier:
   - `openclaw models auth setup-token`
   - `openclaw models auth paste-token`
   - `openclaw models auth login --provider <id>`
- **Channel bot/API tokens:** set/update with channel commands (for example `channels add --channel telegram --token ...`) and related config paths.
- **Other integration API keys (for example web search/provider keys):** set via OpenClaw config paths (for example `tools.web.search.apiKey`) using `openclaw config set`.

Use CLI flows for gateway/provider/channel credentials. Do not require custom entrypoint-based secret export for normal operations.

Compatibility note (this deployment): OpenClaw `2026.2.19` accepts `openclaw config set <path> <value>` but rejects `--strict-json` on `config set`.

### Secure CLI token handling

- Prefer interactive prompts (`openclaw models auth paste-token`) instead of putting tokens in command arguments.
- If automation is required, pass tokens via environment/secret files, never plaintext in shell history.
- After auth changes, verify with:
   - `./services/openclaw/openclaw.sh models status --probe`
- Re-run security checks when changing auth surface:
   - `./services/openclaw/openclaw.sh security audit --deep`

### Auth validation steps

1. Confirm service health first:
   - `./services/openclaw/openclaw.sh gateway status`
2. Confirm gateway auth is configured:
   - `./services/openclaw/openclaw.sh config get gateway.auth.mode`
   - `./services/openclaw/openclaw.sh config get gateway.auth.token`
3. Confirm auth mode/token path from config:
   - `cd services/openclaw && ./openclaw.sh pull-config`
   - Verify `gateway.auth` and related gateway settings in `openclaw.json`.
4. If auth/config changed, apply with Swarm refresh:
   - `ssh pi@pi.local "docker service update --force openclaw_gateway"`

### Unauthorized errors

If commands fail with `unauthorized` / auth errors:

- Use wrapper commands (not direct host `openclaw ...`) to ensure injected env is applied.
- Re-check `gateway.auth` settings via `config get`.
- For provider auth failures, refresh auth profiles via `models auth setup-token` / `models auth paste-token` and re-run `models status --probe`.
- For channel auth failures, re-run `channels add --channel <name> --token <token>` (or channel-specific login flow), then verify with `channels status --probe`.
- Re-run `doctor` and `channels status --probe` after service refresh.

## Safe command ladder (first response to issues)

Run in this order and stop when root cause is identified:

1. `./services/openclaw/openclaw.sh status`
2. `./services/openclaw/openclaw.sh gateway status`
3. `./services/openclaw/openclaw.sh logs --follow`
4. `./services/openclaw/openclaw.sh doctor`
5. `./services/openclaw/openclaw.sh channels status --probe`

## High-confidence operations

### Channels

- List: `./services/openclaw/openclaw.sh channels list`
- Add Telegram: `./services/openclaw/openclaw.sh channels add --channel telegram --token <bot-token>`
- Login WhatsApp: `./services/openclaw/openclaw.sh channels login --channel whatsapp`
- Logs: `./services/openclaw/openclaw.sh channels logs --channel all`

### Device/pairing

- Pending devices: `./services/openclaw/openclaw.sh devices list`
- Approve pairing code: `./services/openclaw/openclaw.sh pairing approve telegram <code>`

### Skills visibility (OpenClaw runtime)

- `./services/openclaw/openclaw.sh skills list`
- `./services/openclaw/openclaw.sh skills list --eligible`
- `./services/openclaw/openclaw.sh skills info <name>`
- `./services/openclaw/openclaw.sh skills check`

## Swarm-specific constraint (critical)

Do **not** rely on `openclaw gateway restart` for this repository deployment. OpenClaw restart helpers assume host service managers (`systemctl --user` / `launchctl`) that are not the source of truth in this Swarm setup.

Use this instead when a restart is required:

- `ssh pi@pi.local "docker service update --force openclaw_gateway"`

## Config workflow (repo standard)

- Run config sync commands from `services/openclaw` so local file paths are consistent.
- Pull remote config: `cd services/openclaw && ./openclaw.sh pull-config`
- Edit local `services/openclaw/openclaw.json`
- Push config back: `cd services/openclaw && ./openclaw.sh push-config`
- If required, force service refresh via Swarm update command above.

## Guardrails

- Ask for explicit confirmation before destructive operations (`reset`, `uninstall`, deleting channel entries, wiping sessions/workspace).
- Prefer non-destructive diagnostics first (`status`, `doctor`, `gateway status`, logs).
- For automation/parsing, prefer commands with `--json` where available.
- Keep secrets out of chat output and repository files.
