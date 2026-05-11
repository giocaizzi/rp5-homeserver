# 🌱 Greenhouse

> Smart plant irrigation system with evidence-based plant care, multi-sensor
> conflict resolution, weather-aware decisions, and a learning loop.

**URL**: `https://greenhouse.home`

Upstream: [giocaizzi/greenhouse](https://github.com/giocaizzi/greenhouse)

---

## 🚀 Quick Start

1. Create the two Tuya Cloud secrets (see [Secrets](#-secrets)).
2. Deploy via Portainer → Swarm mode (Remote Stack from this repo).
3. Open `https://greenhouse.home` and onboard clusters/plants/irrigators.

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

> ⚠️ The container actuates physical irrigation hardware. MCP at `/mcp` is
> blocked at the nginx vhost — the upstream project flags it as
> unauthenticated and localhost-only until auth lands.

---

## 🔐 Secrets

| Secret | Generate |
|--------|----------|
| `greenhouse_tuya_client_id` | `echo -n '<your client id>' \| docker secret create greenhouse_tuya_client_id -` |
| `greenhouse_tuya_client_secret` | `echo -n '<your client secret>' \| docker secret create greenhouse_tuya_client_secret -` |

Get the values from the Tuya IoT Cloud project ("Authorization Key").

---

## ⚙️ Configuration

Tunables in `docker-compose.yml` `environment:`:

| Variable | Default | Purpose |
|----------|---------|---------|
| `TUYA_REGION` | `eu` | Tuya Cloud region (`eu` / `us` / `cn` / `in`) |
| `TZ` | `Europe/Rome` | Container timezone |
| `IRRIGATION_DB_URL` | `sqlite:////app/data/irrigation.db` | DB path inside the volume |
| `IRRIGATION_SYNC_INTERVAL_MINUTES` | `30` | Sensor sync cadence |
| `IRRIGATION_CHECK_INTERVAL_HOURS` | `6` | Decision/actuation cadence (matches global cooldown) |
| `IRRIGATION_WEATHER_LAT` / `_LON` | `45.464` / `9.189` | Open-Meteo coordinates for the precipitation-skip rule |
| `IRRIGATION_ENABLE_SCHEDULER` | `true` | Disable to freeze the system without stopping the stack |

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

After deploy, onboard your devices via the web UI at `https://greenhouse.home`:

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
