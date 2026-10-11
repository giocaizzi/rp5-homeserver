# 📚 Calibre

> Calibre library web UI with Send-to-Kindle, OPDS and KOReader/Kobo sync ([Calibre-Web-Automated](https://github.com/crocodilestick/Calibre-Web-Automated))

**URL**: `https://calibre.giocaizzi.xyz` (public via Cloudflare Tunnel; Access email gate on the UI, path bypass for `/opds`, `/kosync`, `/kobo` — CWA auth is the gate there)

---

## 🚀 Quick Start

1. Deploy via Portainer → Swarm mode (Remote Stack, Webhook GitOps)
2. Import the existing library (see [Library import](#-library-import)) or start empty
3. Log in with `admin` / `admin123` and **change the password immediately**
4. Admin → Basic Configuration → set library path `/calibre-library`, enable uploads
5. Admin → Email Server Settings → Gmail SMTP (see [Send to Kindle](#-send-to-kindle))

---

## 📦 Architecture

| Container | Image | Purpose |
|-----------|-------|---------|
| app | `crocodilestick/calibre-web-automated` | Web UI, ingest watcher, converter, OPDS/sync endpoints |

---

## 🔐 Secrets

No Swarm secrets. The Gmail app password is entered in the admin UI and stored in `app.db` (`config_data` volume, covered by Backrest).

---

## ⚙️ Configuration

| Setting | Value | Purpose |
|---------|-------|---------|
| `PUID` / `PGID` | `1000` | Owner of files in the volumes |
| `NETWORK_SHARE_MODE` | `false` | Local volumes → SQLite WAL enabled |

### 📥 Library import

```bash
# Back up the Mac library first — CWA rewrites metadata.db.
# Library folder must contain metadata.db at its top level.
rsync -a --info=progress2 ~/path/to/Calibre\ Library/ pi@pi.local:/tmp/calibre-import/
ssh pi@pi.local '
  docker service scale calibre_app=0
  sudo rsync -a /tmp/calibre-import/ /var/lib/docker/volumes/calibre_library_data/_data/
  sudo chown -R 1000:1000 /var/lib/docker/volumes/calibre_library_data/_data
  docker service scale calibre_app=1
  rm -rf /tmp/calibre-import'
```

### 📨 Send to Kindle

1. Gmail: create an app password (2FA required).
2. Admin → Email Server Settings: `smtp.gmail.com`, port `587`, STARTTLS, Gmail address + app password, "From" = Gmail address.
3. Amazon → Content & Devices → Preferences → Approved Personal Document E-mail List: add the Gmail address.
4. Profile → set the Kindle address (`…@kindle.com`).

### 📖 Adding books

- UI: upload button (admin must enable uploads).
- Ingest: files dropped in `/cwa-book-ingest` are imported, converted to EPUB and deleted.

---

## 💾 Volumes

| Volume | Mount | Purpose |
|--------|-------|---------|
| `config_data` | `/config` | `app.db`, settings, SMTP credentials |
| `library_data` | `/calibre-library` | Calibre library (`metadata.db` + books) |
| `ingest_data` | `/cwa-book-ingest` | Transient ingest folder |
