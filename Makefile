.DEFAULT_GOAL := help
.PHONY: help lint test check

COMPOSE_FILES := infra/docker-compose.yml $(wildcard services/*/docker-compose.yml)
DOCKERFILES := $(wildcard services/*/Dockerfile)
# hadolint binary when installed, else its container image (CI runners have Docker)
HADOLINT ?= $(shell command -v hadolint 2>/dev/null || echo docker run --rm -v "$(CURDIR)":/w -w /w hadolint/hadolint hadolint)

help: ## List targets
	@grep -E '^[a-z]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-6s %s\n", $$1, $$2}'

# Compose files read DOMAIN / PI_SSH_USER at deploy time; lint with placeholders.
lint: ## Validate compose files, shell scripts, Dockerfiles and the MCP registry
	@for f in $(COMPOSE_FILES); do DOMAIN=example.com PI_SSH_USER=pi CC_ACCOUNT_ID=0 CC_SETTLEMENT_SOURCE_ID=0 docker compose -f $$f config -q || exit 1; done
	git ls-files '*.sh' | xargs shellcheck -S error -e SC1008
	$(HADOLINT) $(DOCKERFILES)
	workers/mcp-connector/render-config.sh --check

test: ## No test suite (config repo); health checks run post-deploy
	@echo "no tests"

check: lint test ## lint + test
