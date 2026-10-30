# 🔑 Pocket ID

> Passkey-only OIDC identity provider; a Cloudflare Access login method ([Pocket ID](https://pocket-id.org))

**URL**: `https://id.<domain>` (public via Cloudflare Tunnel, deliberately **no** Access app after bootstrap: Cloudflare's servers call the token and JWKS endpoints, so Access in front would break the login. Passkey-only login is the gate.)

---

## 🚀 Quick Start

1. Create the secret in Secrets Manager (project `rp5-homeserver`):

   | Key | Value |
   |-----|-------|
   | `pocket-id_encryption_key` | `openssl rand -base64 32`, stored **without** a trailing newline (Pocket ID reads the file byte for byte). Also needed to restore a backup. |

2. Sync it to the Pi: `PI_SSH_USER=pi ./scripts/create_secrets.sh pocket-id`
3. Portainer → Stacks → Add stack → Repository (Swarm, GitOps webhook), compose path `services/pocket-id/docker-compose.yml`, env `DOMAIN=<domain>`. Copy the webhook id into the `WEBHOOK_ID_POCKET_ID` secret of the `pi-services` environment.
4. First admin, Cloudflare wiring and recovery: see [docs/pocket-id.md](../../docs/pocket-id.md).

---

## 📦 Architecture

| Container | Image | Purpose |
|-----------|-------|---------|
| app | `ghcr.io/pocket-id/pocket-id` | OIDC provider, passkey login, admin UI (SQLite) |

---

## 🔐 Secrets

| Swarm secret | Used by | Purpose |
|--------------|---------|---------|
| `pocket-id_encryption_key` (`pocket-id_encryption_key_v<N>` after a [key rotation](../../docs/pocket-id.md#encryption-key-rotation); the compose `secrets.encryption_key.name` is authoritative) | app | Encrypts sensitive data in the database (`ENCRYPTION_KEY_FILE`) |

---

## ⚙️ Settings

Settings come from environment variables (`UI_CONFIG_DISABLED=true`), not the admin UI. Change them in `docker-compose.yml` by PR.

---

## 💾 Volumes

| Volume | Mount | Purpose |
|--------|-------|---------|
| `app_data` | `/app/data` | SQLite database and uploads (dumped to `pocket-id.zip` via `pocket-id export` before each Backrest snapshot) |
