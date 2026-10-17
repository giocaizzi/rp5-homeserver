# Stdio-only MCP servers behind supergateway (stdio -> Streamable HTTP).
# One gateway process, one URL path per server (servers.jsonc), one server
# process per MCP session. Multi-arch base (arm64 for the Pi). Runs as `node`.
FROM node:22.23.3-bookworm-slim

COPY --from=ghcr.io/astral-sh/uv:0.13.1 /uv /usr/local/bin/uv

# Python for the servers: uv-managed, outside any home dir so `node` can run it.
ENV UV_PYTHON_INSTALL_DIR=/opt/python \
    UV_PYTHON_PREFERENCE=only-managed \
    UV_NO_CACHE=1
RUN uv python install 3.12

# One venv per server, from a hash-locked requirements file (servers/<name>.txt,
# compiled from servers/<name>.in; see README).
COPY servers/*.txt /opt/mcp/requirements/
RUN uv venv /opt/mcp/fli --python 3.12 \
    && uv pip install --python /opt/mcp/fli --require-hashes -r /opt/mcp/requirements/fli.txt

# supergateway, pinned with its whole dependency tree.
WORKDIR /opt/gateway
COPY gateway/package.json gateway/package-lock.json ./
RUN npm ci --omit=dev --ignore-scripts && npm cache clean --force
COPY servers.jsonc /etc/supergateway/servers.jsonc

# hadolint ignore=DL3066
USER node
WORKDIR /home/node
ENV HOME=/home/node

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD ["node", "-e", "fetch('http://127.0.0.1:8000/healthz').then(r=>process.exit(r.ok?0:1),()=>process.exit(1))"]

ENTRYPOINT ["/opt/gateway/node_modules/.bin/supergateway"]
CMD ["--config", "/etc/supergateway/servers.jsonc"]
