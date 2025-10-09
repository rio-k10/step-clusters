ENV_FILE   ?= .env
-include $(ENV_FILE)

TF         = terraform -chdir=infrastructure
TFVARS     = -var="aws_profile=$(AWS_PROFILE)" -var="aws_region=$(AWS_REGION)"

.PHONY: check-env build synth deploy diff destroy bootstrap login format test

check-env:
	@if [ ! -f $(ENV_FILE) ]; then \
	  echo ".env file not found."; \
	  exit 1; \
	fi
	@if [ -z "$(AWS_PROFILE)" ]; then \
	  echo "AWS_PROFILE not set in .env"; \
	  exit 1; \
	fi
	@if [ -z "$(AWS_REGION)" ]; then \
	  echo "AWS_REGION not set in .env"; \
	  exit 1; \
	fi
	@if [ -z "$(STAGE)" ]; then \
	  echo "STAGE not set in .env"; \
	  exit 1; \
	fi
	@echo "Environment loaded."
	aws sts get-caller-identity --profile $(AWS_PROFILE) >/dev/null

build:
	pnpm install
	pnpm run build
	cd infrastructure
	$(TF) init -upgrade
	$(TF) workspace select $(STAGE)
	cd ..

plan: check-env build
	pnpm run format
	$(TF) plan $(TFVARS)

apply: check-env
	$(TF) apply --auto-approve $(TFVARS)

destroy: check-env
	$(TF) destroy --auto-approve $(TFVARS)

init: check-env
	$(TF) init -upgrade
	@if ! $(TF) workspace select $(STAGE) >/dev/null 2>&1; then \
	  $(TF) workspace new $(STAGE); \
	fi

login:
	aws sso login --profile $(AWS_PROFILE)