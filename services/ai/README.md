# 🤖 AI Stack (Ollama + OpenWebUI)

> Local LLM inference and chat UI stack optimized for Raspberry Pi 5

**URLs**: `https://chat.home` (OpenWebUI), `https://ai.home` (Ollama API)

---

## 🚀 Quick Start

1. Deploy via Portainer → Swarm mode
2. Access chat UI at `https://chat.home`
3. Access API at `https://ai.home`

---

## 📦 Architecture

| Container | Image | Purpose |
|-----------|-------|---------|
| llm | `ollama/ollama:latest` | LLM inference server |
| chat | `ghcr.io/open-webui/open-webui:v0.8.5` | Web chat interface for Ollama |

---

## 🔐 Secrets

| Secret | Purpose |
|--------|---------|
| `webui_secret_key` | OpenWebUI session and app secret |

---

## ⚙️ Pi Constraints

Raspberry Pi 5 (8GB) limitations:

| Setting | Value | Reason |
|---------|-------|--------|
| Max VRAM | 1GB | Shared memory |
| Flash attention | Disabled | ARM compatibility |
| Concurrent models | 1 | Memory limits |
| Model management | Manual | Pull models explicitly when needed |

---

## ⚙️ Configuration

- OpenWebUI targets Ollama via `OLLAMA_BASE_URL=http://llm:11434` on the private stack network.
- Ollama API remains reachable through nginx at `https://ai.home`.
- OpenWebUI is exposed through nginx at `https://chat.home`.

## 💾 Volumes

| Volume | Purpose |
|--------|---------|
| `ollama_data` | Ollama models and runtime data |
| `openwebui_data` | OpenWebUI app/backend data |