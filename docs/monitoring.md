# Monitoring

## Host Monitoring

### Netdata
Lightweight real-time monitoring installed directly on the Raspberry Pi host (not containerized).

**Installation:**
```bash
# On RP5 host
bash <(curl -Ss https://my-netdata.io/kickstart.sh)
```

**Access:**
- Via nginx proxy: `https://netdata.local` (recommended)
- Direct access: `http://pi.local:19999` (fallback)
- Lightweight dashboard with real-time metrics
- No authentication required (internal network only)