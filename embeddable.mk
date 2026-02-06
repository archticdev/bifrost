# Get the directory of this Makefile
BIFROST_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

bifrost: bifrost-config
	@cd $(BIFROST_DIR)
	docker compose -f docker-compose.bifrost.yml up -d --force-recreate

bifrost-restart: bifrost-config
	@cd $(BIFROST_DIR)
	docker compose -f docker-compose.bifrost.yml restart

	@cd $(BIFROST_DIR) && pwd && ./generate.sh config.yml
$(BIFROST_DIR)docker-compose.bifrost.yml: $(BIFROST_DIR)config.yml $(BIFROST_DIR)docker-compose.template.yml $(BIFROST_DIR)generate.sh

bifrost-config: $(BIFROST_DIR)docker-compose.bifrost.yml

bifrost-down: bifrost-config
	- cd $(BIFROST_DIR) && docker compose -f docker-compose.bifrost.yml down
