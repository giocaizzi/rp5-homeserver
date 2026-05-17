#!/usr/bin/env bash
# ff-api.sh — authenticated curl against the Firefly III REST API.
#
# Resolves the Personal Access Token from the firefly_access_token swarm secret
# mounted in the firefly_scheduler container, then exec'es curl inside the
# firefly_app container so the request stays on the rp5_firefly overlay network
# and the token never crosses the host shell.
#
# Usage:
#   ff-api.sh <METHOD> <PATH> [BODY]
#
#   METHOD  HTTP verb (GET | POST | PUT | DELETE | PATCH)
#   PATH    Path beginning with "/api/v1/..." OR a fully-qualified URL on the
#           public host (https://firefly.giocaizzi.xyz/...). A bare path is
#           sent against http://localhost:8080 inside the app container.
#   BODY    Optional. One of:
#             - inline JSON string:  '{"name":"x"}'
#             - @/abs/path/to/file:  body read from that file (sent as-is)
#             - -                  : body read from stdin
#           Omit for GET/DELETE.
#
# Environment:
#   PI_SSH_USER   SSH user (default: giorgiocaizzi)
#   PI_HOST       SSH host (default: pi.local)
#   FF_RAW        If set to "1", print response headers + body, no jq.
#
# Examples:
#   ff-api.sh GET  /api/v1/about
#   ff-api.sh GET  '/api/v1/accounts?type=asset&limit=100'
#   ff-api.sh POST /api/v1/transactions @./tx.json
#   echo '{"name":"Coffee"}' | ff-api.sh POST /api/v1/categories -

set -euo pipefail

PI_SSH_USER="${PI_SSH_USER:-giorgiocaizzi}"
PI_HOST="${PI_HOST:-pi.local}"
SSH_TARGET="${PI_SSH_USER}@${PI_HOST}"

usage() {
  sed -n '2,32p' "$0" >&2
  exit 64
}

[ "$#" -lt 2 ] && usage

METHOD="$(echo "$1" | tr '[:lower:]' '[:upper:]')"
TARGET="$2"
BODY_ARG="${3-}"

case "$METHOD" in
  GET|POST|PUT|DELETE|PATCH) ;;
  *) echo "ff-api: unknown method '$METHOD'" >&2; usage ;;
esac

# Resolve the URL: bare path => internal; full URL => external.
if [[ "$TARGET" == http://* || "$TARGET" == https://* ]]; then
  URL="$TARGET"
else
  case "$TARGET" in
    /*) URL="http://localhost:8080${TARGET}" ;;
    *)  URL="http://localhost:8080/${TARGET}" ;;
  esac
fi

# Materialise the body.
BODY=""
case "$BODY_ARG" in
  "")  ;;                                             # no body
  -)   BODY="$(cat)" ;;                               # stdin
  @*)  BODY="$(cat "${BODY_ARG#@}")" ;;               # @file
  *)   BODY="$BODY_ARG" ;;                            # inline
esac

# Encode the body so we can ship it through one SSH heredoc without quoting hell.
B64_BODY=""
if [ -n "$BODY" ]; then
  B64_BODY="$(printf %s "$BODY" | base64 | tr -d '\n')"
fi

REMOTE_SCRIPT=$(cat <<'REMOTE'
set -euo pipefail
: "${FF_METHOD:?ff-api: FF_METHOD not set}"
: "${FF_URL:?ff-api: FF_URL not set}"
B64_BODY="${FF_BODY_B64:-}"
RAW="${FF_RAW:-0}"

SCHED=$(docker ps --filter 'label=com.docker.swarm.service.name=firefly_scheduler' --format '{{.Names}}' | head -1)
APP=$(docker ps --filter 'label=com.docker.swarm.service.name=firefly_app' --format '{{.Names}}' | head -1)
[ -z "$SCHED" ] && { echo "ff-api: firefly_scheduler container not found" >&2; exit 1; }
[ -z "$APP" ]   && { echo "ff-api: firefly_app container not found" >&2; exit 1; }

TOKEN=$(docker exec "$SCHED" cat /run/secrets/firefly_access_token)
[ -z "$TOKEN" ] && { echo "ff-api: firefly_access_token secret is empty" >&2; exit 1; }

CURL_ARGS=(-sS -X "$FF_METHOD"
  -H "Accept: application/json"
  -H "Authorization: Bearer ${TOKEN}")

[ "$RAW" = "1" ] && CURL_ARGS=(-i "${CURL_ARGS[@]}")

if [ -n "$B64_BODY" ]; then
  CURL_ARGS+=(-H "Content-Type: application/json" --data-binary "@-")
  printf %s "$B64_BODY" | base64 -d | docker exec -i "$APP" curl "${CURL_ARGS[@]}" "$FF_URL"
else
  docker exec "$APP" curl "${CURL_ARGS[@]}" "$FF_URL"
fi
REMOTE
)

ssh -o BatchMode=yes "$SSH_TARGET" \
  "FF_METHOD=$(printf %q "$METHOD") \
   FF_URL=$(printf %q "$URL") \
   FF_BODY_B64=$(printf %q "$B64_BODY") \
   FF_RAW=$(printf %q "${FF_RAW:-0}") \
   bash -s" <<<"$REMOTE_SCRIPT"
