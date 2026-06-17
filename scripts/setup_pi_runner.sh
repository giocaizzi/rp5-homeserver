#!/usr/bin/env bash
# Install + register a self-hosted GitHub Actions runner ON the Pi, as a
# systemd service, so deploy-infra.yml can run `sync_infra.sh --local`.
#
# Run this ON the Pi, as the user that owns /home/<user>/rp5-homeserver/infra
# (that user must also be in the `docker` group). Re-running re-registers the
# runner (--replace), so it is safe to re-run after a token expires.
#
# Required:
#   GITHUB_REPO    owner/repo (e.g. giocaizzi/rp5-homeserver)
#   RUNNER_TOKEN   registration token from
#                  GitHub -> Settings -> Actions -> Runners -> New self-hosted runner
#                  (short-lived; copy it right before running this)
#
# Optional:
#   RUNNER_LABELS  comma list (default: rp5)
#   RUNNER_NAME    runner name (default: rp5-$(hostname))
#   RUNNER_VERSION pin a version (default: latest release)
#   RUNNER_DIR     install dir (default: $HOME/actions-runner)
#
# Usage:
#   GITHUB_REPO=giocaizzi/rp5-homeserver RUNNER_TOKEN=XXXX ./scripts/setup_pi_runner.sh

set -euo pipefail

: "${GITHUB_REPO:?GITHUB_REPO required (e.g. giocaizzi/rp5-homeserver)}"
: "${RUNNER_TOKEN:?RUNNER_TOKEN required (GitHub -> Settings -> Actions -> Runners -> New self-hosted runner)}"

RUNNER_LABELS="${RUNNER_LABELS:-rp5}"
RUNNER_NAME="${RUNNER_NAME:-rp5-$(hostname)}"
RUNNER_DIR="${RUNNER_DIR:-$HOME/actions-runner}"

ok()   { printf "  \033[0;32m✓\033[0m %s\n" "$*"; }
info() { printf "\033[0;34m▸\033[0m %s\n" "$*"; }
warn() { printf "  \033[1;33m!\033[0m %s\n" "$*"; }
die()  { printf "  \033[0;31m✗\033[0m %s\n" "$*" >&2; exit 1; }

# ---------- Sanity checks ----------
arch="$(uname -m)"
case "$arch" in
  aarch64|arm64) RUNNER_ARCH="arm64" ;;
  x86_64)        RUNNER_ARCH="x64" ;;
  *)             die "Unsupported arch: $arch (expected aarch64)";;
esac
info "Architecture: $arch -> runner arch $RUNNER_ARCH"

command -v docker >/dev/null 2>&1 || die "docker not found on PATH"
if ! docker info >/dev/null 2>&1; then
  die "Cannot talk to Docker. Add this user to the docker group: sudo usermod -aG docker $USER (then re-login)."
fi
ok "Docker reachable as $USER"

command -v curl >/dev/null 2>&1 || die "curl required"
command -v tar  >/dev/null 2>&1 || die "tar required"

# ---------- Resolve version ----------
if [ -z "${RUNNER_VERSION:-}" ]; then
  info "Resolving latest runner release"
  # Read into a var first — piping curl into grep -m1 trips SIGPIPE under
  # `set -o pipefail` (curl exit 23). Parse with a bash regex, no pipes.
  api_json="$(curl -fsSL https://api.github.com/repos/actions/runner/releases/latest)"
  if [[ "$api_json" =~ \"tag_name\"[[:space:]]*:[[:space:]]*\"v?([^\"]+)\" ]]; then
    RUNNER_VERSION="${BASH_REMATCH[1]}"
  fi
  [ -n "${RUNNER_VERSION:-}" ] || die "Could not resolve latest runner version (set RUNNER_VERSION)"
fi
RUNNER_VERSION="${RUNNER_VERSION#v}"
ok "Runner version: $RUNNER_VERSION"

# ---------- Download ----------
mkdir -p "$RUNNER_DIR"
cd "$RUNNER_DIR"
tarball="actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz"
if [ ! -x "$RUNNER_DIR/config.sh" ]; then
  info "Downloading $tarball"
  curl -fsSL -o "$tarball" \
    "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${tarball}"
  tar xzf "$tarball"
  rm -f "$tarball"
  ok "Runner extracted to $RUNNER_DIR"
else
  ok "Runner already present in $RUNNER_DIR"
fi

# ---------- Stop existing service (re-run safe) ----------
if [ -f "$RUNNER_DIR/.service" ]; then
  info "Existing service detected — stopping before re-config"
  sudo ./svc.sh stop  >/dev/null 2>&1 || true
  sudo ./svc.sh uninstall >/dev/null 2>&1 || true
fi

# ---------- Configure ----------
info "Registering runner '$RUNNER_NAME' (labels: $RUNNER_LABELS) on $GITHUB_REPO"
./config.sh \
  --unattended \
  --replace \
  --url "https://github.com/${GITHUB_REPO}" \
  --token "$RUNNER_TOKEN" \
  --name "$RUNNER_NAME" \
  --labels "$RUNNER_LABELS" \
  --work "_work"
ok "Runner registered"

# ---------- Install as service ----------
info "Installing + starting systemd service (runs as $USER)"
sudo ./svc.sh install "$USER"
sudo ./svc.sh start
ok "Service started"

cat <<EOF

────────────────────────────────────────────────────────────
Self-hosted runner is up.

Verify:  GitHub -> Settings -> Actions -> Runners  (status: Idle)
Logs:    sudo journalctl -u 'actions.runner.*' -f
Service: cd $RUNNER_DIR && sudo ./svc.sh status

Next: set repo variable PI_DEPLOY_USER=$USER and create the
'pi-production' environment, then push a change under infra/.
────────────────────────────────────────────────────────────
EOF
