# 📰 Miniflux

> Minimalist feed reader: follow sites and get new articles in one place ([Miniflux](https://miniflux.app))

**URL**: `https://miniflux.<domain>` (public via Cloudflare Tunnel; Access email gate on the whole host, no bypassed paths — Miniflux login is a second factor)

---

## 🚀 Quick Start

1. Create the secrets in Secrets Manager (project `rp5-homeserver`), hex only so the password needs no URL escaping in `DATABASE_URL`:

   | Key | Value |
   |-----|-------|
   | `miniflux_postgres_password` | `openssl rand -hex 32` |
   | `miniflux_admin_password` | `openssl rand -hex 16` (store it in your password manager too) |

2. Sync them to the Pi: `PI_SSH_USER=pi ./scripts/create_secrets.sh miniflux`
3. Portainer → Stacks → Add stack → Repository (Swarm, GitOps webhook), compose path `services/miniflux/docker-compose.yml`, env `DOMAIN=<domain>`. Copy the webhook id into the `WEBHOOK_ID_MINIFLUX` secret of the `pi-services` environment.
4. Open `https://miniflux.<domain>`, log in as `admin` with the admin password.

The public hostname, nginx route and Access apps ship with the `infra` and `cloud` changes; see [adding a public service](../../docs/ci_cd.md).

---

## 📦 Architecture

| Container | Image | Purpose |
|-----------|-------|---------|
| app | `miniflux/miniflux` | Web UI, feed poller, REST/Fever/Google Reader APIs |
| db | `postgres:16-alpine` | Feeds, entries, users, settings |

---

## 🔐 Secrets

| Swarm secret | Used by | Purpose |
|--------------|---------|---------|
| `miniflux_postgres_password` | db, app | Postgres password; the app entrypoint builds `DATABASE_URL` from it |
| `miniflux_admin_password` | app | Admin password, applied on start (`CREATE_ADMIN=1`) |

---

## 📖 Usage

- **Add a site:** Feeds → Add subscription → paste the site URL; Miniflux discovers the feed.
- **Full articles:** feed → Edit → *Fetch original content*, or a scraper rule for sites that only publish summaries.
- **Notify on new articles (ntfy):** Settings → Integrations → Ntfy: tick *Push entries to Ntfy*, URL `https://ntfy.<domain>`, topic `miniflux`, API token = Secrets Manager `miniflux_ntfy_token` (user `alerts`, write-only on `miniflux`; see [ntfy alert topics](../ntfy/README.md#-alert-topics)). Then tick *Push notifications to ntfy* per feed (feed → Edit); both switches are required.
- **Phone:** open the site in the mobile browser and add it to the home screen (Miniflux is a PWA). Native reader apps (Fever / Google Reader API) can't pass Cloudflare Access; enabling them needs a path-scoped bypass app (see Calibre in `cloud/main.tf`).
- **Automations (n8n):** Settings → Integrations → Webhook sends new entries to an n8n webhook.

---

## 💾 Volumes

| Volume | Mount | Purpose |
|--------|-------|---------|
| `postgres_data` | `/var/lib/postgresql/data` | Database (dumped to `miniflux.sql` before each Backrest snapshot) |
