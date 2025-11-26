# Langfuse - LLM Observability Platform

LLM observability and tracing platform for monitoring AI/LLM applications.

## Access

- **URL**: `https://langfuse.home`
- **Default User**: `admin@langfuse.local`

## Architecture

- **langfuse**: Main web application (Next.js)
- **langfuse-worker**: Async event processing worker
- **langfuse-db**: PostgreSQL database
- **langfuse-redis**: Redis for cache and queues
- **clickhouse**: ClickHouse OLAP database for analytics
- **minio**: S3-compatible object storage

## Secrets Required

Create secret files in `secrets/` before deployment:

```bash
# Generate encryption key (64 hex chars)
openssl rand -hex 32 > secrets/langfuse_encryption_key.txt

# Generate salt
openssl rand -base64 32 > secrets/langfuse_salt.txt

# Generate NextAuth secret
openssl rand -base64 32 > secrets/langfuse_nextauth_secret.txt

# Admin password
echo "your-admin-password" > secrets/langfuse_admin_password.txt

# API keys (generate or use existing)
echo "pk-lf-homeserver-$(openssl rand -hex 8)" > secrets/langfuse_public_key.txt
echo "sk-lf-homeserver-$(openssl rand -hex 16)" > secrets/langfuse_secret_key.txt
```

Then create Docker secrets:

```bash
cat secrets/langfuse_encryption_key.txt | docker secret create langfuse_encryption_key -
cat secrets/langfuse_salt.txt | docker secret create langfuse_salt -
cat secrets/langfuse_nextauth_secret.txt | docker secret create langfuse_nextauth_secret -
cat secrets/langfuse_admin_password.txt | docker secret create langfuse_admin_password -
cat secrets/langfuse_public_key.txt | docker secret create langfuse_public_key -
cat secrets/langfuse_secret_key.txt | docker secret create langfuse_secret_key -
```

## SDK Configuration

Use these environment variables in your applications:

```bash
LANGFUSE_HOST=https://langfuse.home
LANGFUSE_PUBLIC_KEY=<from secret>
LANGFUSE_SECRET_KEY=<from secret>
```

> At the moment this is not exposed, send traces with pure OTEL SDKs to central OTEL (Alloy) collector at `https://otel.home`.

## Deployment

Deploy via Portainer using remote repository feature pointing to this folder.

## Network

- Internal network: `rp5_langfuse`
- External network: `rp5_public` (for nginx proxy)
