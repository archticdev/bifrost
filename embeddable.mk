# Get the directory of this Makefile
BIFROST_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

bifrost: bifrost-config
	@cd $(BIFROST_DIR) && docker compose up -d

bifrost-restart: bifrost-config
	@cd $(BIFROST_DIR) && docker compose restart

$(BIFROST_DIR)docker-compose.yml: $(BIFROST_DIR)config.yml $(BIFROST_DIR)docker-compose.template.yml $(BIFROST_DIR)generate.sh
	@cd $(BIFROST_DIR) && pwd && ./generate.sh config.yml

bifrost-config: $(BIFROST_DIR)docker-compose.yml

bifrost-down: bifrost-config
	- cd $(BIFROST_DIR) && docker compose down
