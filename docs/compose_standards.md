# Compose Standards

Docker Compose / Swarm conventions for every stack under `infra/` and `services/`.

## Docker Compose Standardization

Use YAML anchors for common configuration:

```yaml
x-labels-base: &labels-base
  com.giocaizzi.namespace: "<stack-name>"
  com.giocaizzi.env: "production"

x-deploy-base: &deploy-base
  mode: replicated
  replicas: 1
  placement:
    constraints:
      - node.role == manager
  restart_policy:
    condition: any
    delay: 5s
    max_attempts: 3
    window: 120s

x-logging-base: &logging-base
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"

x-security-base: &security-base
  security_opt:
    - no-new-privileges:true
```

**Service template:**
```yaml
service-name:
  image: <image>
  hostname: <hostname>
  # depends_on: [<services>]
  # ports:                              # host-exposed only (DNS, HTTP ingress)
  #   - "<host>:<container>"
  expose:
    - "<port>"
  # command: [...]
  environment:
    - KEY=value
    # - KEY_FILE=/run/secrets/<secret>  # if image supports _FILE suffix
  secrets:
    - <secret_name>
  volumes:
    - <volume>:<path>
    # - ./<config>:<path>:ro            # bind mount for local configs
  # configs:
  #   - source: <config_name>
  #     target: <path>
  #     mode: 0444
  # entrypoint:                         # wrap secrets into env vars
  #   - /bin/sh
  #   - -c
  #   - |
  #     export VAR=$$(cat /run/secrets/<secret>)
  #     exec <original-entrypoint>
  networks:
    - <stack>_network
    # - rp5_public                       # required for nginx-proxied services
  healthcheck:
    test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:<port>/<path>"]
    interval: 30s
    timeout: 10s
    retries: 3
    start_period: 30s                   # adjust per service startup time
  labels:
    <<: *labels-base
    com.giocaizzi.service: "<service>"      # matches compose service key
    com.giocaizzi.component: "<component>"  # app | data | worker | gateway
    com.giocaizzi.tier: "<tier>"            # critical | core | extra
    com.giocaizzi.technology: "<tech>"      # image/tool name (postgres, redis, nginx...)
  <<: *security-base
  # user: "<uid>:<gid>"
  deploy:
    <<: *deploy-base
    labels:
      com.giocaizzi.tier: "<tier>"        # service-level — required for Shepherd filter
    resources:
      limits:
        memory: <limit>M                # required for ARM64
      # reservations:
      #   memory: <reserve>M            # memory-critical services only
  logging:
    <<: *logging-base
```

> **Tier label must appear in both blocks.** `labels:` (top-level) sets container labels; Shepherd filters on **service** labels via `docker service ls --filter` and needs `deploy.labels.com.giocaizzi.tier`. Omitting the deploy-level tier silently disables Shepherd auto-updates for that service.

**Component values:** `app`, `data`, `worker`, `gateway`.

**Naming patterns:**

| Element | Pattern | Example |
|---------|---------|--------|
| Service key | `<function>` | `db`, `app`, `db-exporter` |
| Hostname | `<stack>-<service>` | `n8n-db`, `infra-proxy` |
| Network | `<stack>_network` | `n8n_network` |
| Volume | `<purpose>_data` | `postgres_data` |
| Secret | `<name>` | `postgres_password` |

See [Naming & Labeling Standards](./naming_labels.md) for complete reference.

---

## Swarm Guidelines

1. Minimal stack files with clear separation of concerns.
2. Always use `deploy:` blocks (healthchecks, restart policies, placement, resources).
3. Use Swarm secrets for credentials.
4. Named overlay networks only for required inter-service communication.
5. Named volumes for persistent data; absolute host paths only for backup targets (`/home/pi/`, `/var/lib/docker/volumes`).
6. Preserve original entrypoints when wrapping secrets.
