#!/bin/bash

# smartd -M exec hook: publish a SMART alert to ntfy
#
# Runs on the Pi host as root, invoked by smartd (not by hand). Install to
# /usr/local/bin/smartd_ntfy.sh (root, 755) and reference it from
# /etc/smartd.conf with `-M exec /usr/local/bin/smartd_ntfy.sh`.
# Setup runbook: docs/setup.md#nvme-health-smart
#
# Config file (root-only, mode 600): ${SMARTD_NTFY_ENV:-/etc/smartd_ntfy.env}
#   NTFY_URL         - ntfy base URL, e.g. https://ntfy.<domain>
#   NTFY_TOPIC       - topic to publish to (`rp5`)
#   NTFY_TOKEN_FILE  - file holding the ntfy access token (root-only, mode 600)
#   NTFY_CURL_OPTS   - optional extra curl flags, word-split (e.g. -k --resolve ntfy.home:443:127.0.0.1 for the internal self-signed endpoint)
#
# Environment set by smartd: SMARTD_DEVICE, SMARTD_FAILTYPE, SMARTD_MESSAGE,
# SMARTD_SUBJECT. Exits non-zero on any failure so smartd logs it.

set -euo pipefail

ENV_FILE="${SMARTD_NTFY_ENV:-/etc/smartd_ntfy.env}"

# shellcheck source=/dev/null
source "$ENV_FILE"
: "${NTFY_URL:?NTFY_URL missing in $ENV_FILE}"
: "${NTFY_TOPIC:?NTFY_TOPIC missing in $ENV_FILE}"
: "${NTFY_TOKEN_FILE:?NTFY_TOKEN_FILE missing in $ENV_FILE}"
NTFY_CURL_OPTS="${NTFY_CURL_OPTS:-}"

device="${SMARTD_DEVICE:-unknown}"
failtype="${SMARTD_FAILTYPE:-unknown}"
message="${SMARTD_MESSAGE:-SMART event on $device ($failtype)}"
# Header values must be single-line.
title="$(printf '%s' "${SMARTD_SUBJECT:-SMART $failtype on $device}" | tr '\r\n' '  ')"

auth="$(tr -d '\r\n' <"$NTFY_TOKEN_FILE")"
[ -n "$auth" ] || { echo "empty credential file $NTFY_TOKEN_FILE" >&2; exit 1; }

# The credential travels through a /dev/fd header file, never on the command line.
# shellcheck disable=SC2086 # intentional word-splitting of extra curl flags
printf '%s' "$message" | curl --silent --show-error --fail --max-time 20 \
  -H @<(printf 'Authorization: Bearer %s\n' "$auth") \
  -H "Title: $title" \
  -H "Priority: high" \
  -H "Tags: warning,floppy_disk,smartd" \
  --data-binary @- \
  $NTFY_CURL_OPTS \
  "${NTFY_URL%/}/${NTFY_TOPIC}" >/dev/null
