# 🛡️ AdGuard Home

> DNS server with ad blocking and privacy protection

**URL**: `https://adguard.home`

---

## 🚀 Quick Start

1. Deploy via Portainer → Swarm mode
2. Access `https://adguard.home`
3. Complete setup wizard (see below)
4. Configure clients to use Pi's IP as DNS

---

## 📦 Architecture

| Container | Image | Purpose |
|-----------|-------|---------|
| adguard | `adguard/adguardhome:latest` | DNS server + web UI |

**Exposed Ports** (host-level for DNS):
- `53/tcp`, `53/udp` — Plain DNS
- `853/tcp` — DNS-over-TLS
- `853/udp` — DNS-over-QUIC
- `5443/tcp`, `5443/udp` — DNSCrypt

---

## 🔐 Secrets

No deployment secrets required. Admin credentials set during setup wizard.

For Homepage integration, add to infra secrets after setup:
```bash
echo "your-admin-password" > infra/secrets/adguard_password.txt
./scripts/sync_infra.sh
```

---

## 📖 Initial Setup Wizard

On first access, complete the wizard with these settings:

### Step 1: Admin Web Interface
| Setting | Value | Note |
|---------|-------|------|
| Listen interface | `All interfaces` | ✅ |
| Port | `3000` | ⚠️ **Change from 80** (nginx conflict) |

### Step 2: DNS Server
| Setting | Value |
|---------|-------|
| Listen interface | `All interfaces` |
| Port | `53` (default) |

### Step 3: Authentication
Create admin username and strong password.

### Step 4: Upstream DNS
| Provider | Address |
|----------|---------|
| Cloudflare | `1.1.1.1` |
| Google | `8.8.8.8` |
| Quad9 | `9.9.9.9` (privacy) |

---

## 🌐 DNS Protocols

| Protocol | Port | Endpoint |
|----------|------|----------|
| Plain DNS | 53 | `pi.local` |
| DNS-over-HTTPS | 443 | `https://adguard.home/dns-query` |
| DNS-over-TLS | 853/tcp | `adguard.home` |
| DNS-over-QUIC | 853/udp | `adguard.home` |
| DNSCrypt | 5443 | — |

---

## 📱 Client Configuration

### Router (network-wide)
```
Primary DNS:   192.168.1.100  (Pi's IP)
Secondary DNS: 1.1.1.1        (fallback)
```

### iOS/Android (DNS-over-HTTPS)
```
URL: https://adguard.home/dns-query
```

### Browser (Firefox/Chrome DoH)
```
URL: https://adguard.home/dns-query
```

### Test DNS resolution
```bash
dig @pi.local google.com
nslookup portainer.home pi.local
```

---

## 🏠 DNS Rewrites for `.home` Domains

Configure DNS rewrites to resolve internal services:

1. AdGuard → Filters → DNS rewrites
2. Add entries:

| Domain | Answer |
|--------|--------|
| `*.home` | `192.168.1.100` (Pi's IP) |

Or individual entries:
```
portainer.home → 192.168.1.100
grafana.home   → 192.168.1.100
n8n.home       → 192.168.1.100
```

See [docs/dns.md](../../docs/dns.md) for complete setup.

---

## 💾 Volumes

| Volume | Purpose |
|--------|---------|
| `adguard_conf` | Configuration (`AdGuardHome.yaml`) |
| `adguard_work` | Statistics, query logs |

