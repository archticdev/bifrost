# Get the directory of this Makefile
MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

bifrost: bifrost-config
	@cd $(MAKEFILE_DIR) && docker compose up -d --force-recreate

$(MAKEFILE_DIR)docker-compose.yml: $(MAKEFILE_DIR)config.yml $(MAKEFILE_DIR)docker-compose.bifrost-template.yml $(MAKEFILE_DIR)generate-config.sh
	@cd $(MAKEFILE_DIR) && ./generate-config.sh

bifrost-config: $(MAKEFILE_DIR)docker-compose.yml

bifrost-down:
	@cd $(MAKEFILE_DIR) && docker compose down
