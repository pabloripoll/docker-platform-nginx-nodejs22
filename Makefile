# This Makefile requires GNU Make.
MAKEFLAGS += --silent

# Settings
ifeq ($(strip $(OS)),Windows_NT) # is Windows_NT on XP, 2000, 7, Vista, 10...
    DETECTED_OS := Windows
	C_BLU=''
	C_GRN=''
	C_RED=''
	C_YEL=''
	C_END=''
else
    DETECTED_OS := $(shell uname) # same as "uname -s"
	C_BLU='\033[0;34m'
	C_GRN='\033[0;32m'
	C_RED='\033[0;31m'
	C_YEL='\033[0;33m'
	C_END='\033[0m'
endif

include .env

WEBAPP_BRANCH:=develop
WEBAPP_PROJECT:=$(PROJECT_NAME) - APPWEB
WEBAPP_CONTAINER:=$(addsuffix -$(WEBAPP_CAAS), $(PROJECT_LEAD))

DATABASE_CONTAINER:=$(addsuffix -$(DATABASE_CAAS), $(PROJECT_LEAD))

ROOT_DIR=$(patsubst %/,%,$(dir $(realpath $(firstword $(MAKEFILE_LIST)))))
DIR_BASENAME=$(shell basename $(ROOT_DIR))

.PHONY: help

# -------------------------------------------------------------------------------------------------
#  Help
# -------------------------------------------------------------------------------------------------

help: ## shows this Makefile help message
	echo "Usage: $$ make "${C_GRN}"[target]"${C_END}
	echo ${C_GRN}"Targets:"${C_END}
	awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9_-]+:.*?## / {printf "$$ make \033[0;33m%-30s\033[0m %s\n", $$1, $$2}' ${MAKEFILE_LIST} | column -t -c 2 -s ':#'

# -------------------------------------------------------------------------------------------------
#  System
# -------------------------------------------------------------------------------------------------
.PHONY: local-hostname local-ownership local-ownership-set

local-hostname: ## shows local machine ip and container ports set
	echo "Container Address:"
	echo ${C_BLU}"LOCAL: "${C_END}"$(word 1,$(shell hostname -I))"
	echo ${C_BLU}"APIREST: "${C_END}"$(word 1,$(shell hostname -I)):"$(WEBAPP_PORT)

user ?= ${USER}
group ?= root
local-ownership: ## shows local ownership
	echo $(user):$(group)

local-ownership-set: ## sets recursively local root directory ownership
	$(SUDO) chown -R ${user}:${group} $(ROOT_DIR)/

# -------------------------------------------------------------------------------------------------
#  WEB Application Service
# -------------------------------------------------------------------------------------------------
.PHONY: webapp-hostcheck webapp-info webapp-set webapp-create webapp-network webapp-ssh webapp-start webapp-stop webapp-destroy

webapp-hostcheck: ## shows this project ports availability on local machine for apirest container
	cd platform/$(WEBAPP_PLTF) && $(MAKE) port-check

webapp-info: ## shows the apirest docker related information
	cd platform/$(WEBAPP_PLTF) && $(MAKE) info

webapp-set: ## sets the apirest enviroment file to build the container
	cd platform/$(WEBAPP_PLTF) && $(MAKE) env-set

webapp-create: ## creates the apirest container from Docker image
	cd platform/$(WEBAPP_PLTF) && $(MAKE) build up

webapp-network: ## creates the apirest container network - execute this recipe first before others
	$(MAKE) webapp-stop
	cd platform/$(WEBAPP_PLTF) && $(DOCKER_COMPOSE) -f docker-compose.yml -f docker-compose.network.yml up -d

webapp-ssh: ## enters the apirest container shell
	cd platform/$(WEBAPP_PLTF) && $(MAKE) ssh

webapp-start: ## starts the apirest container running
	cd platform/$(WEBAPP_PLTF) && $(MAKE) start

webapp-stop: ## stops the apirest container but its assets will not be destroyed
	cd platform/$(WEBAPP_PLTF) && $(MAKE) stop

webapp-destroy: ## destroys completly the apirest container
	echo ${C_RED}"Attention!"${C_END};
	echo ${C_YEL}"You're about to remove the "${C_BLU}"$(WEBAPP_PROJECT)"${C_END}" container and delete its image resource."${C_END};
	@echo -n ${C_RED}"Are you sure to proceed? "${C_END}"[y/n]: " && read response && if [ $${response:-'n'} != 'y' ]; then \
        echo ${C_GRN}"K.O.! container has been stopped but not destroyed."${C_END}; \
    else \
		cd platform/$(WEBAPP_PLTF) && $(MAKE) stop clear destroy; \
		echo -n ${C_GRN}"Do you want to clear DOCKER cache? "${C_END}"[y/n]: " && read response && if [ $${response:-'n'} != 'y' ]; then \
			echo ${C_YEL}"The following command is delegated to be executed by user:"${C_END}; \
			echo "$$ $(DOCKER) system prune"; \
		else \
			$(DOCKER) system prune; \
			echo ${C_GRN}"O.K.! DOCKER cache has been cleared up."${C_END}; \
		fi \
	fi

# -------------------------------------------------------------------------------------------------
#  Backend REST API Tests
# -------------------------------------------------------------------------------------------------
.PHONY: webapp-test-up webapp-test-down webapp-test-full test-qa-full

webapp-test-up: ## creates a side database for tests, executes migrations and default seeders, and optionally access the apirest container
	$(DOCKER) exec -it $(DATABASE_CONTAINER) sh -c 'dropdb -f $(DATABASE_NAME)_testing -U "$(DATABASE_USER)"; createdb $(DATABASE_NAME)_testing -U "$(DATABASE_USER)"';
	$(DOCKER) exec -it $(WEBAPP_CONTAINER) sh -c 'echo "Testing:"; \
php artisan config:clear; \
php artisan cache:clear; \
php artisan route:clear; \
composer dump-autoload; \
php artisan --env=testing migrate; \
php artisan --env=testing db:seed --class=TestBaseSeeder;';
	echo ${C_YEL}"$(PROJECT_NAME) TESTING DATABASE"${C_END}" inside container "${C_YEL}"$(DATABASE_CONTAINER)"${C_END}" has been created."
	@echo -n ${C_YEL}"Do you want to enter into the container to perform tests? "${C_END}"[y/n]: " && read response && if [ $${response:-'n'} != 'y' ]; then \
        echo ${C_GRN}"OK!"${C_END}" Remember to drop testing database outside container: "${C_BLU}"$$ make webapp-test-down"${C_END}; \
    else \
		$(MAKE) webapp-ssh; \
	fi

webapp-test-down: ## drops the side database for testing
	$(DOCKER) exec -it $(DATABASE_CONTAINER) sh -c 'dropdb -f $(DATABASE_NAME)_testing -U "$(DATABASE_USER)"';
	echo ${C_YEL}"$(PROJECT_NAME) TESTING DATABASE"${C_END}" inside container "${C_YEL}"$(DATABASE_CONTAINER)"${C_END}" has been deleted."

webapp-test-full: ## creates a side database for testing, executes full tests and drops the side database
	$(DOCKER) exec -it $(DATABASE_CONTAINER) sh -c 'dropdb -f $(DATABASE_NAME)_testing -U "$(DATABASE_USER)"; createdb $(DATABASE_NAME)_testing -U "$(DATABASE_USER)"';
	echo ${C_YEL}"$(PROJECT_NAME) TESTING DATABASE"${C_END}" inside container "${C_YEL}"$(DATABASE_CONTAINER)"${C_END}" has been created."
	$(DOCKER) exec -it $(WEBAPP_CONTAINER) sh -c 'echo "Testing:"; \
php artisan config:clear; \
php artisan cache:clear; \
php artisan route:clear; \
composer dump-autoload; \
php artisan --env=testing migrate; \
php artisan --env=testing db:seed --class=TestBaseSeeder; \
php artisan test --bail --profile;';
	echo ${C_YEL}"$(PROJECT_NAME) TESTING DATABASE"${C_END}" inside container "${C_YEL}"$(DATABASE_CONTAINER)"${C_END}" has persisted data until next testing execution."

# -------------------------------------------------------------------------------------------------
#  Repository Helper
# -------------------------------------------------------------------------------------------------
.PHONY: repo-flush repo-commit

repo-flush: ## clears local git repository cache specially for updating .gitignore on local IDE
	git rm -rf --cached .; git add .; git commit -m "fix: cache cleared for untracked files"

repo-commit: ## echoes common git commands
	echo "git add . && git commit -m \"feat: ... \" && git push -u origin [branch]"
	echo ${C_YEL}"For fixing pushed commit comment:"${C_END}
	echo "git commit --amend"
	echo "git push --force origin [branch]"
