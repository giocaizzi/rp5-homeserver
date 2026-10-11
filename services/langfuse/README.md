# 🔬 Langfuse

> LLM observability and tracing platform

**URL**: `https://langfuse.home`

---

## 🚀 Quick Start

1. Create secrets (see below)
2. Deploy via Portainer → Swarm mode
3. Login at `https://langfuse.home` with admin credentials

---

## 📦 Architecture

| Container | Image | Purpose |
|-----------|-------|---------|
| langfuse-db | `postgres:16-alpine` | Main database |
| langfuse-cache | `redis:7-alpine` | Cache & queues |
| langfuse-analytics | `clickhouse/clickhouse-server` | Analytics OLAP |
| langfuse-storage | `minio/minio` | Object storage |
| langfuse-app | `langfuse/langfuse` | Web application |
| langfuse-worker | `langfuse/langfuse-worker` | Event processor |

---

## 🔐 Secrets

Create all before deployment:

### Application Secrets

| Secret | Generate |
|--------|----------|
| `langfuse_encryption_key` | `openssl rand -hex 32 \| docker secret create langfuse_encryption_key -` |
| `langfuse_salt` | `openssl rand -hex 32 \| docker secret create langfuse_salt -` |
| `langfuse_nextauth_secret` | `openssl rand -base64 32 \| docker secret create langfuse_nextauth_secret -` |
| `langfuse_admin_password` | `echo -n "your-password" \| docker secret create langfuse_admin_password -` |
| `langfuse_public_key` | `echo "pk-lf-$(openssl rand -hex 16)" \| docker secret create langfuse_public_key -` |
| `langfuse_secret_key` | `echo "sk-lf-$(openssl rand -hex 16)" \| docker secret create langfuse_secret_key -` |

### Internal Service Secrets

| Secret | Generate |
|--------|----------|
| `langfuse_postgres_password` | `openssl rand -base64 24 \| docker secret create langfuse_postgres_password -` |
| `langfuse_clickhouse_password` | `openssl rand -base64 24 \| docker secret create langfuse_clickhouse_password -` |
| `langfuse_minio_password` | `openssl rand -base64 24 \| docker secret create langfuse_minio_password -` |
| `langfuse_redis_password` | `openssl rand -base64 24 \| docker secret create langfuse_redis_password -` |

---

## 🔌 MCP

Langfuse's native MCP endpoint is exposed at `https://langfuse-mcp.giocaizzi.xyz/api/public/mcp` (MCP-only public host; UI stays on `langfuse.home`) for the [mcp-connector](../../workers/mcp-connector/README.md). Auth: Basic with the project key pair (`langfuse_public_key:langfuse_secret_key`). Write tools are enabled by default upstream. The host must be listed in `LANGFUSE_MCP_ALLOWED_HOSTS` (set on `app`).

---

## ⚙️ Configuration

Default admin user: `admin@langfuse.local`

Config files in subdirectories:
- `./clickhouse/` — ClickHouse config
- `./postgres/` — PostgreSQL tuning
- `./redis/` — Redis config

---

## 📖 SDK Integration

### Environment Variables

```bash
LANGFUSE_HOST=https://langfuse.home
LANGFUSE_PUBLIC_KEY=pk-lf-...   # from secret
LANGFUSE_SECRET_KEY=sk-lf-...   # from secret
```

### Python Example

```python
from langfuse import Langfuse

langfuse = Langfuse(
    host="https://langfuse.home",
    public_key="pk-lf-...",
    secret_key="sk-lf-..."
)

trace = langfuse.trace(name="my-trace")
```

> **Note**: Currently not exposed externally. Send traces via OTEL to `https://otel.home` using the observability stack.

---

## 💾 Volumes

| Volume | Purpose |
|--------|---------|
| `langfuse_postgres_data` | PostgreSQL database |
| `langfuse_redis_data` | Redis persistence |
| `langfuse_clickhouse_data` | ClickHouse analytics |
| `langfuse_minio_data` | Object storage |
