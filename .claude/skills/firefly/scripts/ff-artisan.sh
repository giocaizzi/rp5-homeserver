#!/usr/bin/env bash
# ff-artisan.sh — run `php artisan` inside the firefly_app container.
#
# Resolves the running container by Swarm service label so it survives
# replica re-scheduling. All arguments are forwarded verbatim to artisan.
#
# Usage:
#   ff-artisan.sh <artisan-command> [args ...]
#
# Environment:
#   PI_SSH_USER   SSH user (default: giorgiocaizzi)
#   PI_HOST       SSH host (default: pi.local)
#   FF_TTY        Set to "1" to allocate a TTY (for `tinker`, `migrate --pretend`, ...)
#
# Examples:
#   ff-artisan.sh firefly-iii:cron
#   ff-artisan.sh firefly-iii:report-integrity
#   ff-artisan.sh firefly-iii:correct-database
#   ff-artisan.sh firefly-iii:refresh-running-balance --force
#   FF_TTY=1 ff-artisan.sh tinker

set -euo pipefail

PI_SSH_USER="${PI_SSH_USER:-giorgiocaizzi}"
PI_HOST="${PI_HOST:-pi.local}"
SSH_TARGET="${PI_SSH_USER}@${PI_HOST}"

if [ "$#" -lt 1 ]; then
  sed -n '2,21p' "$0" >&2
  exit 64
fi

# Quote each argument for safe transport through `bash -s --`.
ARGS_QUOTED=""
for a in "$@"; do
  ARGS_QUOTED+=" $(printf %q "$a")"
done

SSH_FLAGS=(-o BatchMode=yes)
[ "${FF_TTY:-0}" = "1" ] && SSH_FLAGS=(-t)

ssh "${SSH_FLAGS[@]}" "$SSH_TARGET" bash -s -- "${FF_TTY:-0}" <<REMOTE
set -euo pipefail
FF_TTY="\$1"; shift
APP=\$(docker ps --filter 'label=com.docker.swarm.service.name=firefly_app' --format '{{.Names}}' | head -1)
[ -z "\$APP" ] && { echo "ff-artisan: firefly_app container not found" >&2; exit 1; }

EXEC_FLAGS=()
[ "\$FF_TTY" = "1" ] && EXEC_FLAGS+=(-it)

docker exec "\${EXEC_FLAGS[@]}" "\$APP" php artisan${ARGS_QUOTED}
REMOTE
