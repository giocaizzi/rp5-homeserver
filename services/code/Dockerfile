# Claude Code remote dev environment — CloudCLI web/mobile UI + Claude Code CLI.
# Multi-arch base (arm64 for the Pi). Runs as the unprivileged `node` user.
FROM node:22-bookworm-slim

# --- System tooling for the dev environment ---
# Grouped by what Claude reaches for during real work:
#   vcs/net   git gh openssh-client curl wget   clone/push, fetch, debug
#   search    ripgrep fd-find tree               fast code/file search
#   data      jq                                 JSON (yq binary added below)
#   build     build-essential python3 pip venv pipx  native modules / scripts
#   archive   unzip zip                          packages, artifacts
#   edit/ops  vim nano less tmux procps sqlite3 netcat-openbsd dnsutils iputils-ping
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        wget \
        git \
        tmux \
        openssh-client \
        procps \
        less \
        ripgrep \
        fd-find \
        tree \
        jq \
        build-essential \
        python3 \
        python3-pip \
        python3-venv \
        pipx \
        unzip \
        zip \
        vim \
        nano \
        sqlite3 \
        netcat-openbsd \
        dnsutils \
        iputils-ping \
    # --- GitHub CLI (official apt repo) ---
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y --no-install-recommends gh \
    # fd ships as `fdfind` on Debian — expose the conventional `fd` name
    && ln -s "$(command -v fdfind)" /usr/local/bin/fd \
    # yq (mikefarah, Go) — YAML/JSON/XML processor, matches build arch
    && curl -fsSL "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_$(dpkg --print-architecture)" \
        -o /usr/local/bin/yq \
    && chmod +x /usr/local/bin/yq \
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
