# ntfy

Self-hosted push notification service.

## Configuration

Private instance configured via `server.yml`:

- **Authentication:** `deny-all` default access, login enabled
- **Message cache:** SQLite-based, 24h retention
- **Attachments:** Enabled, 15MB per file, 1GB total cache
- **iOS support:** Upstream forwarding to ntfy.sh for APNS
- **Reverse proxy:** `behind-proxy` enabled for correct rate limiting

### Configuration Methods

1. **Config file** (`server.yml`): Main configuration, mounted as Swarm config
2. **CLI commands**: Runtime user/ACL management (persists in auth DB)
3. **Declarative users**: Uncomment `auth-users` in `server.yml` for GitOps

### Declarative Users (Optional)

Bcrypt password hashes are **safe to commit** (one-way, not reversible).

```bash
# Generate bcrypt password hash
docker run --rm -it binwiederhier/ntfy user hash
# Enter password when prompted → outputs $2a$10$...
```

Then uncomment in `server.yml`:

```yaml
auth-users:
  - "admin:$2a$10$YOUR_HASH:admin"
```

> ⚠️ **Never commit access tokens** (`tk_...`) — they are bearer credentials.
> Create tokens via CLI and store privately.

## Post-Deployment Setup

After first deployment, create an admin user via CLI:

```bash
# SSH into the Pi
ssh pi@pi.local

# Exec into the container
docker exec -it $(docker ps -q -f name=ntfy_ntfy) /bin/sh

# Create admin user
ntfy user add --role=admin admin

# (Optional) Create access token for API usage
ntfy token add admin
```

## Access Control

Add users and topic permissions:

```bash
# Add regular user
ntfy user add myuser

# Grant topic access
ntfy access myuser alerts rw        # read-write to 'alerts'
ntfy access myuser logs ro          # read-only to 'logs'
ntfy access everyone public ro      # anonymous read access to 'public'

# UnifiedPush support (anonymous write to up* topics)
ntfy access everyone "up*" write
```

## Usage

### Publish (authenticated)

```bash
curl -u admin:PASSWORD \
  -d "Hello from ntfy!" \
  https://ntfy.home/alerts
```

### Subscribe

```bash
curl -u admin:PASSWORD \
  -s https://ntfy.home/alerts/json
```

### With access token

```bash
curl -H "Authorization: Bearer tk_..." \
  -d "Token auth message" \
  https://ntfy.home/alerts
```

## Volumes

| Volume | Path | Purpose |
|--------|------|---------|
| `ntfy_cache` | `/var/cache/ntfy` | Message cache DB, attachments |
| `ntfy_data` | `/var/lib/ntfy` | User/auth database |

## Network

- **Internal:** `rp5_ntfy` (overlay)
- **External:** `rp5_public` (nginx proxy)

## Resources

- **Memory limit:** 256MB
- **Port:** 80 (exposed to nginx via overlay network)
