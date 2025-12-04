# ⚡ n8n

> Workflow automation platform

**URL**: `https://n8n.home`

---

## 🚀 Quick Start

1. Create secrets (see below)
2. Deploy via Portainer → Swarm mode
3. Login at `https://n8n.home` with basic auth credentials

---

## 📦 Architecture

| Container | Image | Purpose |
|-----------|-------|---------|
| n8n-db | `postgres:16-alpine` | Database (Pi-optimized) |
| n8n-app | `n8nio/n8n:latest` | Workflow engine + web UI |

---

## 🔐 Secrets

| Secret | Generate |
|--------|----------|
| `n8n_postgres_password` | `openssl rand -base64 32 \| docker secret create n8n_postgres_password -` |
| `n8n_auth_password` | `openssl rand -base64 32 \| docker secret create n8n_auth_password -` |

---

## ⚙️ Configuration

### Pi Optimizations

PostgreSQL tuned for Raspberry Pi 5 (8GB):

| Setting | Value | Purpose |
|---------|-------|---------|
| `shared_buffers` | 64MB | Memory for caching |
| `effective_cache_size` | 256MB | Query planner hint |
| `max_connections` | 20 | Conservative for ARM |

Config: `./postgres/postgresql.conf`

### n8n Settings

| Setting | Value |
|---------|-------|
| Execution mode | Main process (Pi-optimized) |
| Data retention | 7 days (auto-pruning) |
| Auth | HTTP Basic (`admin` + secret) |

---

## 💾 Volumes

| Volume | Purpose |
|--------|---------|
| `n8n_postgres_data` | Database storage |
| `n8n_data` | Workflows, credentials |