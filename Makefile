.DEFAULT_GOAL := help
SHELL := /bin/bash

.PHONY: help bootstrap up down restart logs ps status \
        ts-status ts-ip ts-shell adguard-url grafana-url \
        caffeinate clean nuke restart-exporter

help: ## Show this help
	@awk 'BEGIN{FS":.*##"; printf "\nTargets:\n"} /^[a-zA-Z_-]+:.*##/ {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

bootstrap: ## First-time setup: copy .env.example to .env
	@test -f .env || cp .env.example .env
	@echo "Edit .env and set TS_AUTHKEY before running 'make up'"
	@echo "  Generate at: https://login.tailscale.com/admin/settings/keys"

up: ## Start the stack
	@test -f .env || (echo "Run 'make bootstrap' first"; exit 1)
	docker compose up -d
	@echo ""
	@echo "Waiting for tailscale to come up..."
	@sleep 5
	@$(MAKE) -s status

down: ## Stop the stack
	docker compose down

restart: ## Restart all services
	docker compose restart

restart-exporter: ## Restart adguard-exporter (after editing .env credentials)
	docker compose restart adguard-exporter

logs: ## Tail logs
	docker compose logs -f --tail=100

ps: ## List containers
	docker compose ps

status: ## Show key URLs and tailnet IP
	@echo ""
	@echo "Tailscale status:"
	@docker compose exec -T tailscale tailscale status 2>/dev/null | head -20 || echo "  (not ready yet — try 'make ts-status' in a few seconds)"
	@echo ""
	@TSIP=$$(docker compose exec -T tailscale tailscale ip -4 2>/dev/null | tr -d '\r\n'); \
	  echo "  Tailnet IPv4:    $$TSIP"; \
	  echo "  AdGuard UI:      http://$$TSIP:3000  (also http://localhost:3000 via the container's loopback)"; \
	  echo "  Grafana UI:      http://localhost:3001  (admin / see GRAFANA_ADMIN_PASSWORD in .env)"; \
	  echo "  Prometheus UI:   http://localhost:9090"
	@echo ""
	@echo "Next: open the AdGuard UI to finish setup wizard, then in Tailscale admin"
	@echo "set Global Nameserver to the tailnet IPv4 above and enable 'Override local DNS'."

ts-status: ## tailscale status inside the container
	docker compose exec tailscale tailscale status

ts-ip: ## Print tailnet IPv4 of the exit node
	@docker compose exec -T tailscale tailscale ip -4

ts-shell: ## Shell into the tailscale container
	docker compose exec tailscale sh

caffeinate: ## Keep the Mac awake while prototyping (Ctrl+C to stop)
	caffeinate -dimsu

clean: ## Stop and remove containers (keep volumes)
	docker compose down

nuke: ## DANGER: stop and remove containers AND volumes (loses tailnet identity, AdGuard config, Grafana state)
	docker compose down -v
