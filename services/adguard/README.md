# AdGuard Home DNS Server & Ad Blocker

Self-hosted DNS server with ad blocking capabilities at `https://adguard.local`.

## Configuration

**Container**: 
- `adguard/adguardhome:latest` - DNS server and web interface

**Authentication**: Web-based initial setup and user management
**Resource Limits**: 256MB RAM, 0.5 CPU

**Network**: 
- Web interface accessible via nginx proxy (port 80 proxied)
- DNS services exposed on host ports (53, 853, 5443)
- DNS-over-HTTPS available via nginx proxy at `https://adguard.local/dns-query`

## Environment Setup

Set environment variables in Portainer Stack → Environment Variables section:

```bash
TZ=UTC  # Timezone (optional, defaults to UTC)
```

## Deployment

Requires [infrastructure stack](../../infra) running first.

Deploy via Portainer using the remote repository feature.

**Nginx Configuration**: AdGuard Home web interface is accessible at `https://adguard.local`

### Deployment Steps:

1. **Deploy via Portainer** pointing to:
   - Repository: `https://github.com/giocaizzi/rp5-homeserver`
   - Container path: `services/adguard/docker-compose.yml`

2. **Set environment variables** in Portainer Stack → Environment Variables (optional):
   ```bash
   TZ=Europe/London  # Set your timezone
   ```

3. **Monitor deployment progress**:
   - Container startup: ~30-60 seconds
   - Initial configuration generation: automatic

4. **Verify successful deployment**:
   ```bash
   # Check container is healthy
   ssh pi@pi.local "docker ps | grep adguard"
   
   # Test DNS resolution
   dig @pi.local google.com
   nslookup google.com pi.local
   ```

5. **Access and setup**:
   - Navigate to `https://adguard.local`
   - Complete initial setup wizard

6. **Homepage integration** (optional):
   - After setup, update infrastructure `.env` file with:
     ```bash
     HOMEPAGE_VAR_ADGUARD_USERNAME=your_admin_username
     HOMEPAGE_VAR_ADGUARD_PASSWORD=your_admin_password
     ```
   - Restart homepage service to enable widget

### Troubleshooting:

**Common Issues:**
- **Port 53 conflicts**: Ensure no other DNS services are running on the Pi
- **DNS resolution fails**: Check that ports 53/tcp and 53/udp are properly exposed
- **Web interface not accessible**: Verify nginx proxy configuration and container health

**Port conflicts with systemd-resolved:**
```bash
# Disable systemd-resolved if it conflicts with port 53
ssh pi@pi.local "sudo systemctl disable systemd-resolved"
ssh pi@pi.local "sudo systemctl stop systemd-resolved"
```

## Initial Setup

1. **Deploy the stack** in Portainer

2. **Access web interface**:
   - Navigate to `https://adguard.local`
   - Complete the initial setup wizard:
     - Set admin username and password
     - Configure listening interfaces
     - Choose DNS upstream servers

3. **Basic DNS configuration**:
   - **Upstream DNS servers**: 
     - Primary: `1.1.1.1` (Cloudflare)
     - Secondary: `8.8.8.8` (Google)
     - Or use: `9.9.9.9` (Quad9) for privacy
   - **Enable DNS-over-HTTPS**: For secure DNS queries
   - **Rate limiting**: Recommended for public-facing deployments

4. **Ad blocking configuration**:
   - Default filter lists are automatically enabled
   - Popular additional lists:
     - EasyList
     - AdGuard Base filter
     - Social media filters
     - Regional filters (based on location)

5. **Client configuration**:
   - **Router level**: Set Pi's IP as primary DNS server in router settings
   - **Device level**: Configure individual devices to use Pi's IP as DNS server
   - **Testing**: Use `https://adguard.local` → Query Log to verify filtering

## DNS Services

AdGuard Home provides multiple DNS protocols:

- **Plain DNS**: Port 53 (TCP/UDP) - Standard DNS
- **DNS-over-HTTPS**: Via nginx proxy at `https://adguard.local/dns-query` - Secure DNS over HTTPS
- **DNS-over-TLS**: Port 853/tcp - Secure DNS over TLS  
- **DNS-over-QUIC**: Port 853/udp - Fast secure DNS
- **DNSCrypt**: Port 5443 - Encrypted DNS

### Client Configuration Examples:

**Router Configuration:**
- Primary DNS: `192.168.1.100` (Pi's IP)
- Secondary DNS: `1.1.1.1` (fallback)

**iOS/Android DNS-over-HTTPS:**
- URL: `https://adguard.local/dns-query`

**Browser DNS-over-HTTPS:**
- Firefox: `https://adguard.local/dns-query`
- Chrome: `https://adguard.local/dns-query`

## Features

**Ad Blocking:**
- Blocks ads, trackers, and malware domains
- Customizable blocklists and allowlists
- Parental controls and safe browsing
- Statistics and query logging

**DNS Services:**
- Fast local DNS resolution
- Custom DNS records and domain overrides
- Upstream DNS selection and fallback
- Multiple secure DNS protocols

**Privacy:**
- Query logging (can be disabled)
- Client identification and statistics
- No data collection or telemetry by default

## Management

**Web Interface**: Access at `https://adguard.local`
- Dashboard with real-time statistics
- Query log and blocked domains
- Filter management and custom rules
- Client settings and access control

**Logs and Monitoring**:
- Query logs: Track DNS requests and blocks
- Statistics: View blocking effectiveness
- Client activity: Monitor device DNS usage

**Filter Updates**:
- Automatic filter list updates
- Manual filter refresh in web interface
- Custom filter rules and exceptions

## Backup

Important data locations:
- Configuration: Volume `adguard_conf` (`AdGuardHome.yaml`)
- Statistics and logs: Volume `adguard_work`

Include volumes in your backup strategy:
```bash
# Backup configuration
ssh pi@pi.local "docker exec adguard cat /opt/adguardhome/conf/AdGuardHome.yaml > /tmp/adguard-config-backup.yaml"

# Restore configuration (stop container first)
ssh pi@pi.local "docker stop adguard"
ssh pi@pi.local "docker cp /tmp/adguard-config-backup.yaml adguard:/opt/adguardhome/conf/AdGuardHome.yaml"
ssh pi@pi.local "docker start adguard"
```

## Network Configuration

**Important**: AdGuard Home requires specific network setup for optimal functionality.

**Pi Network Setup:**
- Static IP recommended for the Raspberry Pi
- Router should point to Pi's IP for DNS
- Ensure port 53 is not blocked by firewall

**Client Testing:**
```bash
# Test DNS resolution
dig @pi.local google.com

# Test ad blocking (should return blocked result)
dig @pi.local doubleclick.net

# Test DNS-over-HTTPS
curl -H "accept: application/dns-json" "https://adguard.local/dns-query?name=google.com&type=A"
```