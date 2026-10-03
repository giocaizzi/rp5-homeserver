#!/bin/bash
# Shared Bitwarden Secrets Manager helpers. Source this file; do not execute it.
#
# Secrets are read from the project named $BWS_PROJECT (default: rp5-homeserver)
# and held in memory only (never written to disk). Needs bws, jq and a
# machine-account token in BWS_ACCESS_TOKEN.

BWS_PROJECT="${BWS_PROJECT:-rp5-homeserver}"
BWS_SECRETS_JSON=""

# Exit with a clear error when the token or tools are missing
check_bws_environment() {
    if [ -z "${BWS_ACCESS_TOKEN:-}" ]; then
        echo -e "${RED:-}Error: BWS_ACCESS_TOKEN environment variable required${NC:-}" >&2
        exit 1
    fi
    local tool
    for tool in bws jq; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            echo -e "${RED:-}Error: $tool not found in PATH${NC:-}" >&2
            exit 1
        fi
    done
}

# Load the project's secrets once into memory
load_bws_secrets() {
    local project_id
    project_id=$(bws project list --color no --output json \
        | jq -r --arg n "$BWS_PROJECT" '[.[] | select(.name == $n)][0].id // empty') || true
    if [ -z "$project_id" ]; then
        echo -e "${RED:-}Error: Secrets Manager project '$BWS_PROJECT' not found or not readable with this token${NC:-}" >&2
        exit 1
    fi
    BWS_SECRETS_JSON=$(bws secret list "$project_id" --color no --output json) || {
        echo -e "${RED:-}Error: cannot list secrets of project '$BWS_PROJECT'${NC:-}" >&2
        exit 1
    }
}

# Print the value of a secret (exactly one match required, no trailing newline)
get_secret_value() {
    local name="$1"
    local count
    count=$(jq --arg k "$name" '[.[] | select(.key == $k)] | length' <<< "$BWS_SECRETS_JSON")
    [ "$count" = "1" ] || return 1
    jq -j --arg k "$name" '.[] | select(.key == $k) | .value' <<< "$BWS_SECRETS_JSON"
}
