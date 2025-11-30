# 🤖 Ollama

> Local LLM inference server optimized for Raspberry Pi 5

**URL**: `https://ollama.home`

---

## 🚀 Quick Start

1. Deploy via Portainer → Swarm mode
2. Wait for model download (~1GB, first run only)
3. Access API at `https://ollama.home`

---

## 📦 Architecture

| Container | Image | Purpose |
|-----------|-------|---------|
| ollama | `ollama/ollama:latest` | LLM inference server |

---

## 🔐 Secrets

No secrets required. API is unauthenticated.

---

## ⚙️ Pi Constraints

Raspberry Pi 5 (8GB) limitations:

| Setting | Value | Reason |
|---------|-------|--------|
| Max VRAM | 1GB | Shared memory |
| Flash attention | Disabled | ARM compatibility |
| Concurrent models | 1 | Memory limits |
| Default model | `qwen3:1.7b` | ~1GB, Pi-optimized |

**Smart Loading**: Custom entrypoint only downloads model if not present (faster restarts).

---

## 📖 API Usage

### Generate Text

```bash
curl https://ollama.home/api/generate \
  -d '{"model": "qwen3:1.7b", "prompt": "Hello!", "stream": false}'
```

### Chat

```bash
curl https://ollama.home/api/chat \
  -d '{
    "model": "qwen3:1.7b",
    "messages": [{"role": "user", "content": "Hello!"}],
    "stream": false
  }'
```

### List Models

```bash
curl https://ollama.home/api/tags
```

**Performance**: ~2-5 tokens/second on Pi 5.

---

## 💾 Volumes

| Volume | Purpose |
|--------|---------|
| `ollama_data` | Models (~1GB per model) |