.DEFAULT_GOAL := help
.PHONY: help lint test check

COMPOSE_FILES := infra/docker-compose.yml $(wildcard services/*/docker-compose.yml)

help: ## List targets
	@grep -E '^[a-z]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-6s %s\n", $$1, $$2}'

lint: ## Validate compose files and shell scripts
	@for f in $(COMPOSE_FILES); do docker compose -f $$f config -q || exit 1; done
	git ls-files '*.sh' | xargs shellcheck -S error -e SC1008

test: ## No test suite (config repo); health checks run post-deploy
	@echo "no tests"

check: lint test ## lint + test
