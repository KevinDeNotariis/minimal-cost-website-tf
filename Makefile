MODULE ?= terraform
TERRAFORM_VERSION ?= 1.4.0
TERRAFORM_STATE_KEY ?= minimal-cost-website/$(MODULE)/tfstate.json
SSM_PARAMETER_TERRAFORM_S3_BUCKET ?= /terraform/statefiles/bucket
AWS_REGION ?= eu-west-1

install-dependencies: install/terraform install/tfscan

terraform-init: terraform/clean terraform/init
terraform-plan: terraform-init terraform/plan
terraform-apply: terraform-init terraform/apply

# --------------------------------------------------------------------
# Dependencies installation
# --------------------------------------------------------------------
install/terraform:
	@echo "Installing terraform..."
	@wget https://releases.hashicorp.com/terraform/$(TERRAFORM_VERSION)/terraform_$(TERRAFORM_VERSION)_linux_arm64.zip
	@unzip terraform_$(TERRAFORM_VERSION)_linux_amd64.zip
	@mv terraform /usr/local/bin/

install/tfscan:
	@echo "Installing tfscan..."
	@curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash || true
	@if [ "$?" != "0" ]; then cp $$(ls -d /tmp/tfsec* | head -n1)/tfsec-linux-amd64 /usr/local/bin/tfsec && chmod +x /usr/local/bin/tfsec; fi

# --------------------------------------------------------------------
# Tfscan targets
# --------------------------------------------------------------------
tfscan/exec:
	@echo "Scanning terraform configurations..."
	@cd $(MODULE) && \
		tfsec .

# --------------------------------------------------------------------
# Terraform targets
# --------------------------------------------------------------------
terraform/clean:
	@echo "Cleaning terraform files..."
	@cd $(MODULE)/ && \
		rm -rf .terraform .terraform.lock.hcl

terraform/init:
	@echo "Running terraform init..."
	@cd $(MODULE) && \
		terraform init \
		-backend-config="bucket=$$(aws ssm get-parameter --name $(SSM_PARAMETER_TERRAFORM_S3_BUCKET) --query "Parameter.Value" --region $(AWS_REGION) | cut -d'"' -f2)" \
		-backend-config="key=$(TERRAFORM_STATE_KEY)" \
		-backend-config="region=$(AWS_REGION)"

terraform/plan:
	@echo "Running terraform plan..."
	@cd $(MODULE) && \
		terraform plan

terraform/apply:
	@echo "Running terraform apply..."
	@cd $(MODULE) && \
		terraform apply

terraform/destroy:
	@echo "Running terraform destroy..."
	@cd $(MODULE) && \
		terraform destroy
