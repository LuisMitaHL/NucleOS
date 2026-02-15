.PHONY: build clean shell cache-clean help

COMPOSE := docker compose

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

build: ## Build the NucleOS image
	mkdir -p output
	$(COMPOSE) up --build builder

clean: ## Remove output images
	rm -rf output/*

shell: ## Open a shell in the builder container
	$(COMPOSE) run --rm --entrypoint /bin/bash builder

cache-clean: ## Purge the apt-cacher-ng cache volume
	$(COMPOSE) down -v

down: ## Stop all services
	$(COMPOSE) down
