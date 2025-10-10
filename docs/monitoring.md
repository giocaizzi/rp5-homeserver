# Monitoring

## Host Monitoring

### Netdata
Lightweight real-time monitoring installed directly on the Raspberry Pi host (not containerized).

**Installation:**
```bash
# On RPi host
bash <(curl -Ss https://my-netdata.io/kickstart.sh)
```

**Access:**
- Local: `http://pi.local:19999`
- Lightweight dashboard with real-time metrics
- No authentication required (internal network only)