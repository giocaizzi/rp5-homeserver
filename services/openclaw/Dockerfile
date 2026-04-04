FROM ghcr.io/openclaw/openclaw:2026.4.2

USER root

RUN apt-get update && apt-get install -y \
    # --- Chromium dependencies ---
    # NSS / NSPR (TLS, crypto)
    libnspr4 \
    libnss3 \
    # ATK / AT-SPI (accessibility)
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libatspi2.0-0 \
    # D-Bus / CUPS (IPC, printing)
    libdbus-1-3 \
    libcups2 \
    # XKB (keyboard)
    libxkbcommon0 \
    # X11 compositing & rendering
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    # GPU / DRM buffer management
    libgbm1 \
    # ALSA (audio)
    libasound2 \
    && rm -rf /var/lib/apt/lists/*

USER node
