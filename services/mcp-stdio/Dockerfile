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

# Garmin (Taxuspt/garmin_mcp) is not on PyPI: its dependencies are hash-locked
# like fli's, the package comes from a checksum-pinned commit tarball, --no-deps.
ADD --checksum=sha256:4e4f2e8167325d60ba4e54957d21d7d4bfa369eeb762838777246976f713e4a5 \
    https://github.com/Taxuspt/garmin_mcp/archive/202913fde53c9d15890d661fc9748dc6d0d5af52.tar.gz \
    /tmp/garmin_mcp.tar.gz
RUN uv venv /opt/mcp/garmin --python 3.12 \
    && uv pip install --python /opt/mcp/garmin --require-hashes -r /opt/mcp/requirements/garmin.txt \
    && uv pip install --python /opt/mcp/garmin --no-deps /tmp/garmin_mcp.tar.gz \
    && rm /tmp/garmin_mcp.tar.gz

# pysurfline (giocaizzi/pysurfline) is private: its wheel comes from the
# `pysurfline` build context (a local `uv build --wheel`, README → Build),
# dependencies hash-locked like fli's, the package itself --no-deps.
# `pysurfline` is a named build context (--build-context), not a stage.
# hadolint ignore=DL3022
COPY --from=pysurfline pysurfline-*-py3-none-any.whl /tmp/
RUN uv venv /opt/mcp/surfline --python 3.12 \
    && uv pip install --python /opt/mcp/surfline --require-hashes -r /opt/mcp/requirements/surfline.txt \
    && uv pip install --python /opt/mcp/surfline --no-deps /tmp/pysurfline-*-py3-none-any.whl \
    && rm /tmp/pysurfline-*-py3-none-any.whl

# supergateway, pinned with its whole dependency tree.
WORKDIR /opt/gateway
COPY gateway/package.json gateway/package-lock.json ./
RUN npm ci --omit=dev --ignore-scripts && npm cache clean --force
COPY servers.jsonc /etc/supergateway/servers.jsonc

# Garmin OAuth tokens (garmin_data volume): pre-created so the volume is
# owned by node on first mount.
RUN install -d -o node -g node -m 700 /home/node/.garminconnect

# hadolint ignore=DL3066
USER node
WORKDIR /home/node
ENV HOME=/home/node

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD ["node", "-e", "fetch('http://127.0.0.1:8000/healthz').then(r=>process.exit(r.ok?0:1),()=>process.exit(1))"]

ENTRYPOINT ["/opt/gateway/node_modules/.bin/supergateway"]
CMD ["--config", "/etc/supergateway/servers.jsonc"]
