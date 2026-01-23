# =============================================================================
# Infrastructure Deployment Makefile
# =============================================================================
# Orchestrates Terraform/OpenTofu and Ansible workflows.
# 
# NOTE: This Makefile assumes Ansible playbooks are in a sibling directory
# structure. Adjust ANSIBLE_PLAYBOOKS_DIR and HELM_CHARTS_DIR as needed.
# =============================================================================

.PHONY: help init plan apply destroy export-outputs setup-env deploy-traefik deploy-cert-manager deploy-rancher deploy-all

# Configuration
TF_DIR := $(shell pwd)
ANSIBLE_PLAYBOOKS_DIR := $(shell dirname $(TF_DIR))/ci-cd-templates/ansible/playbooks
HELM_CHARTS_DIR := $(shell dirname $(TF_DIR))/ci-cd-templates/helm-charts
TF_OUTPUT_JSON := $(TF_DIR)/.terraform-outputs.json

# Detect Terraform/OpenTofu binary
TF_BINARY := $(shell command -v tofu >/dev/null 2>&1 && echo "tofu" || echo "terraform")

help: ## Show this help message
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

init: ## Initialize Terraform/OpenTofu
	cd $(TF_DIR) && $(TF_BINARY) init

plan: ## Plan Terraform changes
	cd $(TF_DIR) && $(TF_BINARY) plan -lock=false

apply: ## Apply Terraform changes (auto-approve, no lock)
	cd $(TF_DIR) && $(TF_BINARY) apply -auto-approve -lock=false
	@$(MAKE) export-outputs

destroy: ## Destroy Terraform infrastructure (auto-approve, no lock)
	cd $(TF_DIR) && $(TF_BINARY) destroy -auto-approve -lock=false

export-outputs: ## Export Terraform outputs to JSON file
	@echo "Exporting Terraform outputs..." >&2
	@cd $(TF_DIR) && $(TF_BINARY) output -json > $(TF_OUTPUT_JSON) 2>/dev/null || (echo "Error: Terraform outputs not available. Run 'make apply' first." >&2 && exit 1)
	@echo "Terraform outputs exported to $(TF_OUTPUT_JSON)" >&2

setup-env: ## Print shell export commands - use with: eval $(make setup-env) - to set environment variables in your shell
	@cd $(TF_DIR) && \
		echo "export KUBECONFIG=\"$$($(TF_BINARY) output -raw kubeconfig_path)\"" && \
		echo "export DOMAIN_NAME=\"$$($(TF_BINARY) output -raw domain_name)\"" && \
		echo "export LETS_ENCRYPT_EMAIL=\"$$($(TF_BINARY) output -raw letsencrypt_email)\"" && \
		echo "export RANCHER_BOOTSTRAP_PASSWORD=\"$$($(TF_BINARY) output -raw rancher_bootstrap_password)\"" && \
		echo "export HELM_CHARTS_PATH=\"$(HELM_CHARTS_DIR)\""

deploy-traefik: ## Deploy Traefik ingress controller
	@echo "Deploying Traefik..."
	@cd $(TF_DIR) && \
		KUBECONFIG="$$($(TF_BINARY) output -raw kubeconfig_path)" \
		HELM_CHARTS_PATH="$(HELM_CHARTS_DIR)" \
		ansible-playbook -i localhost, $(ANSIBLE_PLAYBOOKS_DIR)/deploy-traefik.yaml

deploy-cert-manager: ## Deploy cert-manager
	@echo "Deploying cert-manager..."
	@cd $(TF_DIR) && \
		KUBECONFIG="$$($(TF_BINARY) output -raw kubeconfig_path)" \
		LETS_ENCRYPT_EMAIL="$$($(TF_BINARY) output -raw letsencrypt_email)" \
		ansible-playbook -i localhost, $(ANSIBLE_PLAYBOOKS_DIR)/deploy-cert-manager.yaml

deploy-rancher: ## Deploy Rancher server
	@echo "Deploying Rancher..."
	@cd $(TF_DIR) && \
		KUBECONFIG="$$($(TF_BINARY) output -raw kubeconfig_path)" \
		DOMAIN_NAME="$$($(TF_BINARY) output -raw domain_name)" \
		LETS_ENCRYPT_EMAIL="$$($(TF_BINARY) output -raw letsencrypt_email)" \
		RANCHER_BOOTSTRAP_PASSWORD="$$($(TF_BINARY) output -raw rancher_bootstrap_password)" \
		ansible-playbook -i localhost, $(ANSIBLE_PLAYBOOKS_DIR)/deploy-rancher.yaml

deploy-all: deploy-traefik deploy-cert-manager deploy-rancher ## Deploy all services in order
