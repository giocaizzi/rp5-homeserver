# DNS & Hostname Resolution

Configure DNS to access services via `.home` domains (e.g., `portainer.home`, `firefly.home`).

**Two methods:**
1. **AdGuard DNS rewrites** (recommended) - network-wide automatic resolution
2. **Manual hosts file** - per-device configuration

## Method 1: AdGuard DNS Rewrites (Recommended)

1. **Access AdGuard**: `https://adguard.home`
2. **Navigate to**: **Filters** → **DNS rewrites** → **Add DNS rewrite**
3. **Add wildcard entry**:
   - **Domain**: `*.home`
   - **IP Address**: `192.168.1.100` (replace with your Pi's IP)
   - Click **Save**

This single entry resolves all `.home` domains to the Pi. Nginx handles routing to individual services.

**Alternative**: Add individual domains if wildcard doesn't work:
```
portainer.home → 192.168.1.100
firefly.home → 192.168.1.100
n8n.home → 192.168.1.100
...
```

4. **Configure clients**: Set Pi's IP as DNS in router or per-device

**Verify**:
```bash
nslookup portainer.home
# Should return Pi's IP
```

## Method 2: Manual Hosts File

Edit `/etc/hosts` (Linux/macOS) or `C:\Windows\System32\drivers\etc\hosts` (Windows):

```
192.168.1.100 portainer.home netdata.home backrest.home homepage.home
192.168.1.100 adguard.home firefly.home n8n.home ollama.home
```

**Pros**: Works without AdGuard  
**Cons**: Must configure each device individually

## Router DNS Configuration

1. Access router admin → DHCP/DNS settings
2. **Primary DNS**: `192.168.1.100` (Pi's IP)
3. **Secondary DNS**: `1.1.1.1` (fallback)
4. Save and reboot if required

All devices will use AdGuard DNS after DHCP lease renewal.

## Raspberry Pi Static IP

Ensure static IP to avoid DNS resolution issues.

**Option 1: Router DHCP reservation** (recommended)
- Find MAC: `ip link show`
- Create DHCP reservation in router

**Option 2: Static config on Pi**
```bash
sudo nano /etc/dhcpcd.conf
# Add:
interface eth0
static ip_address=192.168.1.100/24
static routers=192.168.1.1
static domain_name_servers=1.1.1.1 8.8.8.8
```

Choose IP outside router's DHCP range.

## Troubleshooting

**DNS not resolving:**
```bash
# Check AdGuard running
ssh pi@pi.home "docker service ls | grep adguard"

# Test DNS
dig @192.168.1.100 portainer.home
```

**Clear DNS cache:**
```bash
# macOS
sudo dscacheutil -flushcache

# Linux
sudo systemd-resolve --flush-caches

# Windows (PowerShell as Admin)
ipconfig /flushdns
```

**Check client DNS:**
```bash
cat /etc/resolv.conf  # Should show Pi's IP
```

## Notes

- **Wildcard `*.home`** resolves all `.home` domains to Pi; nginx routes to services
- **Static IP required** for Pi to avoid DNS issues
- **Adding services**: With wildcard DNS, just add nginx config—no DNS changes needed
- **Metadata like `SITE_OWNER=admin@firefly.local`** doesn't affect routing, only used internally
