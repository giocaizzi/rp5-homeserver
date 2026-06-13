# 🌱 Greenhouse

> Smart plant irrigation system with evidence-based plant care, multi-sensor
> conflict resolution, weather-aware decisions, and a learning loop.

**URL**: `http://greenhouse.home`

Upstream: [giocaizzi/greenhouse](https://github.com/giocaizzi/greenhouse)

---

## 🚀 Quick Start

1. Create the two Tuya Cloud secrets (see [Secrets](#-secrets)).
2. Deploy via Portainer → Swarm mode (Remote Stack from this repo).
3. Open `http://greenhouse.home` and onboard clusters/plants/irrigators.

---

## 📦 Architecture

| Container | Image | Purpose |
|-----------|-------|---------|
| greenhouse-app | `ghcr.io/giocaizzi/greenhouse:latest` | FastAPI (API + HTMX UI), APScheduler jobs, SQLite archive |

Single-container stack. SQLite is the permanent record; Tuya Cloud is the
live source for sensor reads; actuation goes over the Tuya **local protocol
v3.5** to LAN-resident irrigators.

```
Tuya Cloud (sensors)
        │  reads
        ▼
  greenhouse-app ───► greenhouse_data (SQLite archive)
        │  local v3.5 actuation
        ▼
  Irrigators on LAN
```

> ⚠️ The container actuates physical irrigation hardware. `/mcp` is gated
> by a bearer token (`GREENHOUSE_MCP_TOKEN`, fail-closed since upstream
> v2.0.0): unset → `503`, missing/wrong header → `401`.

---

## 🔐 Secrets

| Secret | Generate |
|--------|----------|
| `greenhouse_tuya_client_id` | `echo -n '<your client id>' \| docker secret create greenhouse_tuya_client_id -` |
| `greenhouse_tuya_client_secret` | `echo -n '<your client secret>' \| docker secret create greenhouse_tuya_client_secret -` |
| `greenhouse_mcp_token` | `openssl rand -hex 32 \| docker secret create greenhouse_mcp_token -` |
| `greenhouse_auth_secret_key` | `openssl rand -hex 32 \| docker secret create greenhouse_auth_secret_key -` |
| `greenhouse_auth_admin_password` | `openssl rand -base64 24 \| docker secret create greenhouse_auth_admin_password -` |

Tuya values come from the Tuya IoT Cloud project ("Authorization Key").
The MCP token is opaque — generate any high-entropy string and share it
with MCP clients via `Authorization: Bearer <token>`.

### Session auth (v3.0.0+)

Since upstream **v3.0.0** every `/api/v1` route (except `/auth/login` and
`/.well-known/*`) and every web page requires a login. Two secrets back it:

- `greenhouse_auth_secret_key` — HS256 key that signs the session JWT.
- `greenhouse_auth_admin_password` — bootstraps the admin user on the **first**
  v3.0.0 boot (username is `admin`, set via `GREENHOUSE_AUTH_ADMIN_USERNAME`).
  Save the generated value before creating the secret; it is the login password.

> **MCP is unaffected.** `/mcp` keeps its own `greenhouse_mcp_token` bearer gate
> (`require_user` also accepts that token), so MCP tool calls work without a
> session. The two auth surfaces are independent — session auth for humans, the
> bearer token for machines.

> **Cookie is non-secure on purpose.** The LAN serves plain HTTP at
> `greenhouse.home`, so a `Secure` cookie would never be sent there and would
> break LAN login. Public access (`greenhouse.giocaizzi.xyz`) is HTTPS via the
> Cloudflare tunnel + CF Access, and the non-secure cookie still rides that
> encrypted path. Public browser users therefore see **two** prompts: the CF
> Access email gate, then the app login.

---

## ⚙️ Configuration

Tunables in `docker-compose.yml` `environment:`:

| Variable | Default | Purpose |
|----------|---------|---------|
| `TUYA_REGION` | `eu` | Tuya Cloud region (`eu` / `us` / `cn` / `in`) |
| `TZ` | `Europe/Rome` | Container timezone |
| `IRRIGATION_DB_URL` | `sqlite:////app/data/irrigation.db` | DB path inside the volume |
| `IRRIGATION_SYNC_INTERVAL_MINUTES` | `30` | Sensor sync cadence |
| `IRRIGATION_CHECK_CRON_HOURS` | `*/6` | Cron hour spec for `check_all` (replaces deprecated `IRRIGATION_CHECK_INTERVAL_HOURS`; engine cooldown still gates actuation) |
| `IRRIGATION_WEATHER_LAT` / `_LON` | `45.464` / `9.189` | Open-Meteo coordinates for the precipitation-skip rule |
| `IRRIGATION_ENABLE_SCHEDULER` | `true` | Disable to freeze the system without stopping the stack |
| `IRRIGATION_AUTH_ENABLED` | `true` | Session auth gate (v3.0.0+). `false` opts out — dev/migration only |
| `GREENHOUSE_AUTH_ADMIN_USERNAME` | `admin` | Bootstrap admin username (password is a secret) |

The local key for each irrigator is fetched from the Tuya Cloud API at
runtime — only the client ID + secret are needed as Swarm secrets.

---

## 💾 Volumes

| Volume | Mount | Purpose |
|--------|-------|---------|
| `greenhouse_data` | `/app/data` | SQLite archive (sensor readings, irrigation events, decision logs, alerts, activity, plant health snapshots) |

The volume is the only writable location in the image (it runs as non-root
UID 1000). Include `greenhouse_data` in your backup target.

### Inspect the SQLite archive

```bash
ssh giorgiocaizzi@pi.local
docker exec -it $(docker ps -qf name=greenhouse_app) \
  sqlite3 /app/data/irrigation.db ".tables"
```

Or copy a snapshot off the Pi:

```bash
docker run --rm -v greenhouse_data:/data -v "$PWD":/out alpine \
  cp /data/irrigation.db /out/irrigation.db
```

---

## 🧪 Initial Setup

After deploy, onboard your devices via the web UI at `http://greenhouse.home`:

1. **Sync from Tuya Cloud** — the app pulls your devices list and offers to
   register the sensors and irrigators it recognizes.
2. **Create clusters** — group plants that share an irrigator.
3. **Add plants** — pick species from the bundled plant database (~80 species
   with evidence-based care thresholds).
4. **Verify a dry run** — toggle the global dry-run banner before live
   actuation if you want to watch decisions without irrigating.

---

## 🔍 Troubleshooting

**Cannot reach Tuya devices on LAN.** The container talks to LAN irrigator
IPs over outbound TCP from the overlay network. If actuation times out,
verify on the Pi:

```bash
docker exec -it $(docker ps -qf name=greenhouse_app) \
  python -c "import socket; s=socket.socket(); s.connect(('<irrigator-ip>', 6668)); print('ok')"
```

(Tuya local protocol uses TCP/6668.)

**Image won't pull.** Confirm GHCR access — the image is public, but
Docker still needs network egress to `ghcr.io`. The first release tag is
`1.0.0` (also published as `latest`).

**Pin to a version.** Override `image:` in the compose file to
`ghcr.io/giocaizzi/greenhouse:1.0.0` for reproducible deploys. The image
ships with cosign-signed SLSA provenance + SBOM (verify via
`cosign verify --certificate-identity-regexp ...` per upstream CD docs).
