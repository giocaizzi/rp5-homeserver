# Code Review Tracker

Comprehensive audit findings for the RP5 Home Server project.

**Last Review:** 2025-12-07  
**Reviewer:** Automated Audit  
**Version:** 1.6.2

---

## Summary

| Category | 🔴 Critical | 🟠 High | 🟡 Medium | 🟢 Low |
|----------|-------------|---------|-----------|--------|
| Security | 0 | 4 | 3 | 0 |
| Standards | 0 | 0 | 3 | 3 |
| Documentation | 0 | 0 | 2 | 2 |
| Architecture | 0 | 0 | 3 | 2 |
| **Total** | **0** | **4** | **11** | **7** |

---

## 🟠 High Priority Issues

### CR-002: Missing Healthcheck on Portainer

| Field | Value |
|-------|-------|
| **Status** | 🟠 Open |
| **File** | `infra/docker-compose.yml` |
| **Lines** | 90-117 |
| **Priority** | P1 |

**Description:**  
Portainer service lacks healthcheck. All other infra services have healthchecks.

**Remediation:**
```yaml
healthcheck:
  test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:9000/api/status"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 30s
```

---

### CR-003: Missing Healthchecks in Observability Stack

| Field | Value |
|-------|-------|
| **Status** | 🟠 Open |
| **File** | `services/observability/docker-compose.yml` |
| **Priority** | P1 |

**Description:**  
Loki, Tempo, and Alloy services have disabled healthchecks with comments citing "scratch-based image". Swarm requires healthchecks for proper orchestration.

**Affected Services:**
- `loki` (lines ~123-150)
- `tempo` (lines ~156-187)
- `alloy` (lines ~190-229)

**Remediation Options:**
1. Use `wget` if available in image
2. Use `nc` (netcat) for TCP port checks
3. Use `/ready` or `/health` endpoints with `curl`

---

### CR-004: Loki Running as Root

| Field | Value |
|-------|-------|
| **Status** | 🟠 Open |
| **File** | `services/observability/docker-compose.yml` |
| **Line** | 143 |
| **Priority** | P1 |

**Description:**
```yaml
user: "root"
```

Violates non-root container guideline.

**Remediation:**  
Fix volume permissions or use init container to set ownership.

---

### CR-005: Homepage Running as Root with Writable Docker Socket

| Field | Value |
|-------|-------|
| **Status** | 🟠 Open |
| **File** | `infra/docker-compose.yml` |
| **Lines** | 253-310 |
| **Priority** | P1 |

**Description:**
```yaml
environment:
  - PUID=0
  - PGID=0
volumes:
  - /var/run/docker.sock:/var/run/docker.sock  # Missing :ro
```

Container escape vector with root privileges.

**Remediation:**  
Add `:ro` suffix if write access not required.

---

### CR-006: Firefly Cron Anti-pattern

| Field | Value |
|-------|-------|
| **Status** | 🟠 Open |
| **File** | `services/firefly/docker-compose.yml` |
| **Lines** | 252-310 |
| **Priority** | P1 |

**Description:**  
Cron container has multiple issues:
1. Runtime package installation (`apk add docker-cli`)
2. Docker socket without `:ro`
3. Complex inline shell script
4. Fragile label-based container discovery

**Remediation:**  
Consider dedicated cron sidecar (e.g., `mcuadros/ofelia`) or Firefly's built-in cron support.

---

## 🟡 Medium Priority Issues

### CR-007: All Images Use `:latest` Tag

| Field | Value |
|-------|-------|
| **Status** | 🟡 Open |
| **Files** | All docker-compose.yml |
| **Priority** | P2 |

**Description:**  
Unpredictable updates, difficult rollbacks, breaks reproducibility.

**Affected Stacks:**
- infra: 6 images
- n8n: 1 image (postgres pinned ✓)
- firefly: 4 images
- langfuse: 6 images
- observability: 5 images
- ollama: 1 image
- ntfy: 1 image
- adguard: 1 image

**Remediation:**  
Pin to specific versions (e.g., `grafana/grafana:10.2.3`).

---

### CR-008: Documentation References Non-Existent File

| Field | Value |
|-------|-------|
| **Status** | 🟡 Open |
| **Priority** | P2 |

**Broken Links:**
| File | Line | Reference |
|------|------|-----------|
| `infra/README.md` | 134 | `docs/dns.md` |
| `services/adguard/README.md` | 128 | `../../docs/dns.md` |

**Remediation:**  
Update links to `docs/networking.md#dns-resolution` or create `docs/dns.md`.

---

### CR-009: Langfuse README Volume Names Incorrect

| Field | Value |
|-------|-------|
| **Status** | 🟡 Open |
| **File** | `services/langfuse/README.md` |
| **Priority** | P2 |

**README Claims:**
- `langfuse_postgres_data`
- `langfuse_redis_data`
- `langfuse_clickhouse_data`
- `langfuse_minio_data`

**Actual Volumes:**
- `langfuse_db`
- No redis volume (cache only)
- `clickhouse_data`, `clickhouse_logs`
- `minio_data`

---

### CR-011: Inconsistent Secret Naming in Infra Stack

| Field | Value |
|-------|-------|
| **Status** | 🟡 Open |
| **File** | `infra/docker-compose.yml` |
| **Priority** | P2 |

**Standard:** `<stack>_<name>`

**Non-compliant secrets:**
- `ssl_cert` → `infra_ssl_cert`
- `ssl_key` → `infra_ssl_key`
- `cloudflared_token` → `infra_cloudflared_token`
- `gcp_service_account` → `infra_gcp_service_account`
- `portainer_api_key` → `infra_portainer_api_key`
- `domain` → `infra_domain`

---

### CR-013: Missing `depends_on` in Langfuse

| Field | Value |
|-------|-------|
| **Status** | 🟡 Open |
| **File** | `services/langfuse/docker-compose.yml` |
| **Priority** | P2 |

**Missing Dependencies:**
| Service | Should Depend On |
|---------|------------------|
| langfuse (app) | langfuse-db, langfuse-redis, clickhouse, minio |
| langfuse-worker | langfuse-db, langfuse-redis, clickhouse |

---

### CR-014: Missing `depends_on` in Observability

| Field | Value |
|-------|-------|
| **Status** | 🟡 Open |
| **File** | `services/observability/docker-compose.yml` |
| **Priority** | P2 |

**Missing Dependencies:**
| Service | Should Depend On |
|---------|------------------|
| grafana | prometheus, loki, tempo |

---

## 🟢 Low Priority Issues

### CR-015: Missing Memory Reservations

| Field | Value |
|-------|-------|
| **Status** | 🟢 Open |
| **Files** | All docker-compose.yml |
| **Priority** | P3 |

**Description:**  
Most services only have `limits`, not `reservations`. Critical services should have both for Swarm scheduling.

---

### CR-016: SSL Configuration Missing Best Practices

| Field | Value |
|-------|-------|
| **Status** | 🟢 Open |
| **File** | `infra/nginx/snippets/ssl-params.conf` |
| **Priority** | P3 |

**Missing:**
- `ssl_session_cache shared:SSL:10m;`
- `ssl_session_timeout 1d;`
- `ssl_stapling on;` (for production certs)
- HSTS header

---

### CR-017: Duplicate PostgreSQL Configs

| Field | Value |
|-------|-------|
| **Status** | 🟢 Open |
| **Priority** | P3 |

**Files:**
- `services/n8n/postgres/postgresql.conf`
- `services/firefly/postgres/postgresql.conf`
- `services/langfuse/postgres/postgresql.conf`

**Recommendation:**  
Create shared base config, override only per-stack settings.

---

### CR-018: Script Uses Deprecated docker-compose

| Field | Value |
|-------|-------|
| **Status** | 🟢 Open |
| **File** | `scripts/sync_infra.sh` |
| **Line** | ~162 |
| **Priority** | P3 |

**Current:** `docker-compose pull`  
**Should be:** `docker compose pull` (v2 syntax)

---

### CR-019: Terraform Missing Remote State Backend

| Field | Value |
|-------|-------|
| **Status** | 🟢 Open |
| **File** | `cloud/main.tf` |
| **Priority** | P3 |

**Description:**  
Local state only. Consider GCS backend for team collaboration/CI.

---

## 🏗️ Architecture Findings

### CR-020: Private Config Pattern Missing (Firefly Importer)

| Field | Value |
|-------|-------|
| **Status** | 🟡 Open |
| **File** | `services/firefly/docker-compose.yml` |
| **Priority** | P2 |
| **Category** | Architecture |

**Description:**  
Firefly importer config (`config.json`) is treated as a secret but contains non-sensitive configuration data (account mappings, import rules, field mappings). This is a "private config" pattern:
- Not sensitive (no credentials)
- User-specific (account IDs, mappings)
- Should not be in git (contains personal financial structure)

**Current Implementation:**
```yaml
secrets:
  - import_config  # Misuses secrets for non-sensitive config
entrypoint:
  - /bin/sh
  - -c
  - |
    cp /run/secrets/import_config /var/www/html/import/config.json
```

**Problem:**  
Swarm secrets are for credentials, not configuration. This conflates two concerns.

**Proposed Pattern — Private Configs:**

Create new mount type category in `.github/copilot-instructions.md`:

| Mount Type | Use Case | Git Tracked | Example |
|------------|----------|-------------|---------|
| **Secrets** | Credentials, tokens, keys | ❌ Never | `db_password`, `api_token` |
| **Configs** | Static app configuration | ✅ Yes | `postgresql.conf`, `nginx.conf` |
| **Private Configs** | User-specific, non-sensitive | ❌ No | Import mappings, personal prefs |

**Remediation Options:**

1. **Volume mount with gitignored file:**
   ```yaml
   volumes:
     - ./private/import-config.json:/var/www/html/import/config.json:ro
   ```
   With `services/firefly/private/.gitignore` containing `*` `!.gitignore`

2. **Named volume with init script:**
   Keep current pattern but document clearly that `firefly_import_config` is a config secret, not credential.

3. **Swarm config (external):**
   ```yaml
   configs:
     import_config:
       external: true
       name: firefly_import_config
   ```
   Create via: `docker config create firefly_import_config ./config.json`

**Recommendation:** Option 1 (volume mount) aligns with existing `infra/homepage/` pattern.

---

### CR-021: Backrest Configuration Not Declarative

| Field | Value |
|-------|-------|
| **Status** | 🟡 Open |
| **File** | `infra/docker-compose.yml` |
| **Priority** | P2 |
| **Category** | Architecture |

**Description:**  
Backrest stores configuration in a volume (`backrest_config:/config`), configured via Web UI. This is:
- Non-declarative (manual UI clicks)
- Not version controlled
- Lost on volume deletion
- Difficult to reproduce

**Current State:**
```yaml
environment:
  - BACKREST_CONFIG=/config/config.json
volumes:
  - backrest_config:/config
```

Backrest supports JSON config file. Configuration should be declarative and tracked.

**Proposed Declarative Approach:**

1. **Export current config:**
   ```bash
   docker cp $(docker ps -qf name=infra_backrest):/config/config.json ./infra/backrest/config.json
   ```

2. **Mount as read-only config:**
   ```yaml
   configs:
     - source: backrest_config
       target: /config/config.json
       mode: 0444
   
   configs:
     backrest_config:
       file: ./backrest/config.json
   ```

3. **Redact secrets from config file** (if any) and inject via entrypoint.

**Benefits:**
- Version controlled backup configuration
- Reproducible setup
- Disaster recovery simplified
- GitOps compatible

**Note:** Config contains repository passwords. Use Swarm config + secret injection pattern, or keep passwords in separate secret and reference via `RESTIC_PASSWORD_FILE`.

---

### CR-022: AdGuard Configuration Not Declarative

| Field | Value |
|-------|-------|
| **Status** | 🟢 Open |
| **File** | `services/adguard/docker-compose.yml` |
| **Priority** | P3 |
| **Category** | Architecture |

**Description:**  
AdGuard stores all configuration in volume (`adguard_conf:/opt/adguardhome/conf`). Includes:
- DNS rewrites (critical for `.home` domain resolution)
- Upstream DNS servers
- Filtering rules
- Client settings

**Current State:**
```yaml
volumes:
  - adguard_conf:/opt/adguardhome/conf
```

**Proposed Declarative Approach:**

AdGuard supports YAML config (`AdGuardHome.yaml`). Extract and track:

1. **Export current config:**
   ```bash
   docker cp $(docker ps -qf name=adguard_adguard):/opt/adguardhome/conf/AdGuardHome.yaml ./services/adguard/AdGuardHome.yaml
   ```

2. **Mount as config:**
   ```yaml
   configs:
     - source: adguard_config
       target: /opt/adguardhome/conf/AdGuardHome.yaml
       mode: 0644
   
   configs:
     adguard_config:
       file: ./AdGuardHome.yaml
   ```

3. **Redact password hash** if committing to git, or use private config pattern.

**Priority:** Lower than Backrest (DNS rewrites are less critical than backup config).

---

### CR-023: Ntfy Users Not Declarative

| Field | Value |
|-------|-------|
| **Status** | 🟢 Open |
| **File** | `services/ntfy/docker-compose.yml` |
| **Priority** | P3 |
| **Category** | Architecture |

**Description:**  
Ntfy users/ACLs are created via CLI (`ntfy user add`) and stored in SQLite database (`ntfy_data:/var/lib/ntfy`). Not version controlled.

**Current:** README documents manual CLI commands after deployment.

**Ntfy Supports Declarative Users:**
```yaml
# server.yml
auth-users:
  - "admin:$2a$10$BCRYPT_HASH:admin"
  - "user:$2a$10$BCRYPT_HASH:user"
```

Bcrypt hashes are safe to commit (one-way, irreversible).

**Remediation:**
1. Generate bcrypt hashes: `docker run --rm -it binwiederhier/ntfy user hash`
2. Add to `server.yml` (already tracked)
3. Document hash generation in README

**Benefits:** Users recreated on fresh deployment without manual CLI.

---

### CR-024: Homepage Config Contains Secrets References

| Field | Value |
|-------|-------|
| **Status** | ✅ Acceptable |
| **File** | `infra/homepage/*.yaml` |
| **Priority** | — |
| **Category** | Architecture |

**Description:**  
Homepage config files are git-tracked and use template variables for secrets:
```yaml
password: "{{HOMEPAGE_FILE_BACKREST_PASSWORD}}"
key: "{{HOMEPAGE_FILE_PORTAINER_API_KEY}}"
```

**Assessment:** ✅ **Correct pattern.** Config is tracked, secrets injected at runtime via environment variables pointing to `/run/secrets/`. This is the ideal separation.

---

## 📊 Config Usage Analysis

### Current Swarm Configs Usage

| Stack | Config | Source | Purpose |
|-------|--------|--------|---------|
| n8n | `postgres_config` | `./postgres/postgresql.conf` | DB tuning |
| firefly | `mariadb_config` | `./mariadb/mariadb.cnf` | DB tuning |
| firefly | `postgres_config` | `./postgres/postgresql.conf` | Pico DB tuning |
| langfuse | `clickhouse_config` | `./clickhouse/config.xml` | OLAP config |
| langfuse | `clickhouse_users` | `./clickhouse/users.xml` | ⚠️ Contains password |
| langfuse | `postgres_config` | `./postgres/postgresql.conf` | DB tuning |
| langfuse | `redis_config` | `./redis/redis.conf` | ⚠️ Contains password |
| ntfy | `ntfy_config` | `./server.yml` | Server config |
| infra | `version_config` | `./VERSION` | Version display |

### Bind Mount Configs (Not Swarm Configs)

| Stack | Mount | Purpose | Tracked |
|-------|-------|---------|---------|
| infra/nginx | `./nginx/nginx.conf` | Reverse proxy | ✅ Yes |
| infra/nginx | `./nginx/snippets/` | Config snippets | ✅ Yes |
| infra/netdata | `./netdata/netdata.conf` | Monitoring | ✅ Yes |
| infra/homepage | `./homepage/` | Dashboard config | ✅ Yes |
| observability | `./prometheus/prometheus.yml` | Metrics scraping | ✅ Yes |
| observability | `./loki/loki-config.yaml` | Log aggregation | ✅ Yes |
| observability | `./tempo/tempo-config.yaml` | Tracing | ✅ Yes |
| observability | `./alloy/` | OTEL collector | ✅ Yes |
| observability | `./grafana/provisioning/` | Datasources/dashboards | ✅ Yes |

### Services Needing Declarative Config

| Service | Current State | Recommended Action | Priority |
|---------|---------------|-------------------|----------|
| **Backrest** | Volume, UI-configured | Export + mount config | P2 |
| **AdGuard** | Volume, UI-configured | Export + mount config | P3 |
| **Ntfy** | Volume, CLI-configured | Add auth-users to server.yml | P3 |
| **Firefly Importer** | Secret (misused) | Private config pattern | P2 |
| **Portainer** | Volume | Keep as-is (state, not config) | — |
| **Grafana** | Provisioning ✅ | Already declarative | — |

---

## ✅ Compliant Areas

| Area | Status | Notes |
|------|--------|-------|
| YAML Anchors | ✅ Pass | Consistent deploy-base, logging-base, security-base |
| Network Naming | ✅ Pass | All follow `rp5_<stack>` pattern |
| Service Secret Naming | ✅ Pass | Services follow `<stack>_<name>` |
| Hostname Naming | ✅ Pass | All follow `<stack>-<service>` |
| Labeling | ✅ Pass | Complete namespace, service, component, role, tier, technology |
| Secrets gitignore | ✅ Pass | Proper `*` with `!.gitignore` |
| Terraform gitignore | ✅ Pass | Excludes tfstate, tfvars, .terraform |
| Documentation Structure | ✅ Pass | Clear organization |
| ARM64 Optimization | ✅ Pass | PostgreSQL tuning, memory limits |
| Rate Limiting | ✅ Pass | nginx zones configured |
| Security Headers | ✅ Pass | X-Content-Type-Options, X-XSS-Protection |

---

## Changelog

| Date | Version | Changes |
|------|---------|---------|
| 2025-12-07 | 1.2 | Removed resolved issues: CR-001 (Langfuse credentials), CR-010 (Pico healthcheck), CR-012 (nginx healthcheck) |
| 2025-12-04 | 1.1 | Added architecture findings: configs analysis, declarative config patterns, private configs concept |
| 2025-11-30 | 1.0 | Initial comprehensive audit |
