# Claude Code remote dev environment — CloudCLI web/mobile UI + Claude Code CLI.
# Multi-arch base (arm64 for the Pi). Runs as the unprivileged `node` user.
FROM node:22-bookworm-slim

# --- System tooling required by the dev environment ---
# git/gh:   clone + push repos from the in-browser shell and from Claude's Bash
# tmux:     persistent multi-session terminals (spawn many sessions, reattach)
# openssh-client: git over SSH + outbound ssh
# wget/ca-certificates: healthcheck + TLS
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        wget \
        git \
        tmux \
        openssh-client \
        procps \
        less \
    # --- GitHub CLI (official apt repo) ---
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# --- Agent CLI + web UI (global installs, owned by root, runnable by node) ---
#   @anthropic-ai/claude-code : the official Claude Code CLI (cloudcli auto-detects it on PATH)
#   @cloudcli-ai/cloudcli     : the self-hosted web/mobile UI (CloudCLI / Claude Code UI)
RUN npm install -g \
        @anthropic-ai/claude-code \
        @cloudcli-ai/cloudcli \
    && npm cache clean --force

USER node
WORKDIR /home/node/workspace

# Bind on all interfaces so nginx (separate overlay container) can reach the UI.
ENV HOME=/home/node \
    HOST=0.0.0.0 \
    PORT=3001 \
    TERM=xterm-256color

EXPOSE 3001

CMD ["cloudcli"]
