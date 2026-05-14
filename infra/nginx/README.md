# 🌐 Nginx Reverse Proxy

Modular nginx configuration for all services.

## 📁 Structure

```
nginx/
├── nginx.conf              # Main config (global settings only)
├── conf.d/
│   ├── globals.conf        # Backend map + rate limits
│   ├── defaults.conf       # Default server + HTTP redirect
│   ├── infra.conf          # Infra services (always up)
│   └── services/           # One file per service (may be down)
│       ├── n8n.conf
│       ├── ollama.conf
│       ├── adguard.conf
│       ├── grafana.conf
│       ├── otel.conf
│       ├── langfuse.conf
│       ├── ntfy.conf
│       ├── firefly.conf
│       └── firefly-importer.conf
└── snippets/
    ├── ssl-params.conf
    ├── proxy-headers.conf
    ├── websocket-support.conf
    ├── static-assets.conf
    ├── error-503.conf
    ├── timeouts-long.conf
    └── timeouts-streaming.conf
```

## 🔧 Service Categories

| Category | Location | Error Handling | Behavior |
|----------|----------|----------------|----------|
| **Infra** | `10-infra.conf` | None | Nginx fails if these fail |
| **Services** | `services/*.conf` | 503 page | Graceful degradation |

**Infra services:** portainer, netdata, backrest, homepage

**Dynamic services:** n8n, ollama, adguard, grafana, langfuse, ntfy, otel, firefly*

## ➕ Adding a New Service

1. Add backend mapping in `conf.d/00-globals.conf`
2. Add hostname to HTTP redirect in `conf.d/01-defaults.conf`
3. Create `conf.d/services/<service>.conf`
4. Test with `nginx -t`

## 📝 Snippets

| Snippet | Purpose |
|---------|---------|
| `ssl-params.conf` | SSL certificates and TLS config |
| `proxy-headers.conf` | Standard proxy headers (Host, X-Real-IP, X-Forwarded-*) |
| `websocket-support.conf` | WebSocket upgrade handling |
| `static-assets.conf` | Static file caching (1h) + rate limiting |
| `error-503.conf` | Generic service unavailable page |
| `timeouts-long.conf` | 300s timeouts for long operations |
| `timeouts-streaming.conf` | 3m timeouts for streaming/long-polling |

## ⚙️ How Fault Tolerance Works

1. **DNS resolver** (`127.0.0.11`) — Docker's embedded DNS, nginx won't fail at startup if service DNS isn't ready
2. **Variable-based proxy_pass** (`set $upstream $backend`) — Resolves at request time, not config load
3. **`error-503.conf`** — Returns friendly error when service is unreachable (502/503/504)

Infra services omit `error-503.conf` because they're expected to always be running with nginx.
