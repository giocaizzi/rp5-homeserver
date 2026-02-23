#!/usr/bin/env bash
# OpenClaw gateway CLI wrapper — runs commands on remote Pi container
#
# Usage: ./openclaw.sh <command> [args...]
#
# Environment variables:
#   PI_HOST     - Pi hostname or IP (default: pi.local)
#   PI_SSH_USER - SSH username (default: giorgiocaizzi)

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

readonly PI_HOST="${PI_HOST:-pi.local}"
readonly PI_SSH_USER="${PI_SSH_USER:-giorgiocaizzi}"
readonly CONTAINER_NAME="openclaw_gateway"
readonly SERVICE_NAME="openclaw_gateway"
readonly CONFIG_PATH="/home/node/.openclaw/openclaw.json"
readonly LOCAL_CONFIG="./openclaw.json"

# =============================================================================
# Functions
# =============================================================================

show_help() {
  cat << EOF
Usage: $0 <command> [args...]

Skill deployment:
  upload-skill <skill-name>  Upload skill from skills/<skill-name>/ to Pi

Special commands:
  edit-config       Edit openclaw.json with vim
  pull-config       Download config from Pi to ./openclaw.json
  push-config       Upload ./openclaw.json to Pi container
  restart           Force restart Swarm service
  shell             Drop into container shell
  help              Show this help

OpenClaw commands:
  doctor            Health checks
  health            Fetch health from gateway
  status            Show channel health
  channels list     List configured channels
  devices list      List paired devices
  onboard           Interactive onboarding

Examples:
  $0 upload-skill router
  $0 edit-config
  $0 pull-config
  $0 push-config
  $0 restart
  $0 doctor
  $0 channels list
  $0 skills list
  $0 pairing approve telegram <code>

EOF
}

get_container_id() {
  ssh -q "${PI_SSH_USER}@${PI_HOST}" \
    "docker ps -q -f name=${CONTAINER_NAME} | head -1" 2>/dev/null || {
      echo "Error: Cannot find container '${CONTAINER_NAME}' on ${PI_HOST}" >&2
      exit 1
    }
}

ensure_vim() {
  local container_id="$1"
  
  if ! ssh -q "${PI_SSH_USER}@${PI_HOST}" \
       "docker exec ${container_id} command -v vim >/dev/null 2>&1"; then
    echo "Installing vim in container..."
    ssh -q "${PI_SSH_USER}@${PI_HOST}" \
      "docker exec -u root ${container_id} sh -c 'apt-get update -qq && apt-get install -y -qq vim'" \
      || {
        echo "Error: Failed to install vim" >&2
        exit 1
      }
  fi
}

exec_pull_config() {
  echo "Downloading config from Pi..."
  ssh -q "${PI_SSH_USER}@${PI_HOST}" \
    "docker exec \$(docker ps -q -f name=${CONTAINER_NAME}) cat ${CONFIG_PATH}" \
    > "${LOCAL_CONFIG}" || {
      echo "Error: Failed to download config" >&2
      exit 1
    }
  echo "Config saved to ${LOCAL_CONFIG}"
}

exec_push_config() {
  if [[ ! -f "${LOCAL_CONFIG}" ]]; then
    echo "Error: ${LOCAL_CONFIG} not found. Run 'pull-config' first." >&2
    exit 1
  fi
  
  echo "Validating JSON..."
  if ! command -v jq >/dev/null 2>&1; then
    echo "Warning: jq not installed, skipping validation"
  elif ! jq empty "${LOCAL_CONFIG}" 2>/dev/null; then
    echo "Error: Invalid JSON in ${LOCAL_CONFIG}" >&2
    exit 1
  fi
  
  echo "Uploading config to Pi..."
  local container_id
  container_id=$(get_container_id)
  
  cat "${LOCAL_CONFIG}" | ssh -q "${PI_SSH_USER}@${PI_HOST}" \
    "docker exec -i ${container_id} sh -c 'cat > ${CONFIG_PATH}'" || {
      echo "Error: Failed to upload config" >&2
      exit 1
    }
  
  echo "Config uploaded successfully. Restart service if needed:"
  echo "  ssh ${PI_SSH_USER}@${PI_HOST} 'docker service update --force openclaw_gateway'"
}

exec_upload_skill() {
  local skill_name="$1"
  
  if [[ -z "${skill_name}" ]]; then
    echo "Error: Skill name required" >&2
    echo "Usage: $0 upload-skill <skill-name>" >&2
    exit 1
  fi
  
  local local_skill_dir="./skills/${skill_name}"
  
  if [[ ! -d "${local_skill_dir}" ]]; then
    echo "Error: Skill directory not found: ${local_skill_dir}" >&2
    exit 1
  fi
  
  if [[ ! -f "${local_skill_dir}/SKILL.md" ]]; then
    echo "Error: SKILL.md not found in ${local_skill_dir}" >&2
    echo "OpenClaw requires SKILL.md for skill auto-discovery" >&2
    exit 1
  fi
  
  echo "Uploading skill '${skill_name}' to Pi..."
  
  local container_id
  container_id=$(get_container_id)
  
  local remote_skill_dir="/home/node/.openclaw/workspace/skills/${skill_name}"
  
  # Create remote skill directory
  ssh -q "${PI_SSH_USER}@${PI_HOST}" \
    "docker exec ${container_id} mkdir -p ${remote_skill_dir}" || {
      echo "Error: Failed to create remote directory" >&2
      exit 1
    }
  
  # Upload all files in skill directory
  for file in "${local_skill_dir}"/*; do
    if [[ -f "${file}" ]]; then
      local filename=$(basename "${file}")
      echo "  Uploading ${filename}..."
      cat "${file}" | ssh -q "${PI_SSH_USER}@${PI_HOST}" \
        "docker exec -i ${container_id} sh -c 'cat > ${remote_skill_dir}/${filename}'" || {
          echo "Error: Failed to upload ${filename}" >&2
          exit 1
        }
    fi
  done
  
  echo "Skill '${skill_name}' uploaded successfully."
  echo "OpenClaw will auto-discover it within ~250ms."
  echo ""
  echo "Verify with: $0 skills list | grep ${skill_name}"
}

exec_edit_config() {
  local container_id
  container_id=$(get_container_id)
  
  ensure_vim "${container_id}"
  
  ssh -t "${PI_SSH_USER}@${PI_HOST}" \
    "docker exec -it ${container_id} vim ${CONFIG_PATH}"
}

exec_shell() {
  local container_id
  container_id=$(get_container_id)
  
  ssh -t "${PI_SSH_USER}@${PI_HOST}" \
    "docker exec -it ${container_id} sh"
}

exec_restart() {
  echo "Restarting OpenClaw service '${SERVICE_NAME}' on ${PI_HOST}..."

  ssh -q "${PI_SSH_USER}@${PI_HOST}" \
    "docker service inspect ${SERVICE_NAME} >/dev/null 2>&1 && docker service update --force ${SERVICE_NAME}" || {
      echo "Error: Failed to restart service '${SERVICE_NAME}'" >&2
      exit 1
    }

  echo "Restart triggered successfully."
}

exec_openclaw_cli() {
  local -a args=("$@")
  local remote_args
  
  # Serialize args safely for remote execution
  remote_args=$(printf '%q ' "${args[@]}")
  remote_args="${remote_args% }"
  
  local container_id
  container_id=$(get_container_id)
  
  ssh -t "${PI_SSH_USER}@${PI_HOST}" \
    "docker exec -it ${container_id} sh -c '\
      export OPENCLAW_GATEWAY_URL=ws://127.0.0.1:18789; \
      exec node /app/dist/index.js \"\$@\"' sh ${remote_args}"
}

# =============================================================================
# Main
# =============================================================================

main() {
  if [[ $# -eq 0 ]]; then
    show_help
    exit 1
  fi
  
  local command="$1"
  shift
  
  case "${command}" in
    edit-config)
      exec_edit_config
      ;;
    pull-config)
      exec_pull_config
      ;;
    push-config)
      exec_push_config
      ;;
    upload-skill)
      exec_upload_skill "$@"
      ;;
    restart)
      exec_restart
      ;;
    shell)
      exec_shell
      ;;
    help|--help|-h)
      show_help
      ;;
    *)
      exec_openclaw_cli "${command}" "$@"
      ;;
  esac
}

main "$@"
