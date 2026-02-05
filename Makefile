# Get the directory of this Makefile
BASTION_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

bifrost: bifrost-config
	@cd $(BASTION_DIR) && docker compose up -d --force-recreate

$(BASTION_DIR)docker-compose.yml: $(BASTION_DIR)config.yml $(BASTION_DIR)docker-compose.bifrost-template.yml $(BASTION_DIR)generate-config.sh
	@cd $(BASTION_DIR) && pwd && ./generate-config.sh

bifrost-config: $(BASTION_DIR)docker-compose.yml

bifrost-down:
	- cd $(BASTION_DIR) && docker compose down
