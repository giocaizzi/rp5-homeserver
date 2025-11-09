# Ollama Local LLM Server

Local AI inference server at `https://ollama.home`, optimized for Raspberry Pi 5.

## Configuration

**Container**: `ollama/ollama:latest`
**Model**: Qwen3:1.7B (~1GB, Pi-optimized)
**Resource Limits**: 3GB RAM, 3 CPU cores (Pi-optimized for 8GB system)
**Access**: API via nginx proxy

## Pi Optimizations

**Hardware Limits**:
- VRAM: 1GB max
- Flash attention: disabled
- Single model loading
- Custom entrypoint for smart model management

**Smart Loading**: Model only downloaded if not present (faster restarts)

## API Usage

**Base URL**: `https://ollama.home`

**Generate Text**:
```bash
curl https://ollama.home/api/generate \
  -d '{"model": "qwen3:1.7b", "prompt": "Hello!", "stream": false}'
```

**Performance**: ~2-5 tokens/second on Pi 5

## Environment Setup

Copy `.env.example` to `.env` and configure memory limits based on available RAM.

**Storage**: ~1GB for default model, plan accordingly for additional models.

## Deployment

Requires [infrastructure stack](../../infra) running first.

> **First run is slow** because it downloads model (several minutes), subsequent starts are fast.