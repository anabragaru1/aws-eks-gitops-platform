# Local helpers only; CI runs the same steps through the workflows.
SHELL := /bin/bash
TF_DIRS := terraform/bootstrap terraform/environments/dev terraform/environments/prod

.PHONY: help fmt validate lint scan k8s api frontend check

help:
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F ':.*## ' '{printf "  %-10s %s\n", $$1, $$2}'

fmt: ## Format Terraform and Go
	terraform fmt -recursive terraform
	cd apps/api && gofmt -w .

validate: ## terraform validate for every root
	@for d in $(TF_DIRS); do echo "== $$d"; terraform -chdir=$$d init -backend=false -input=false >/dev/null && terraform -chdir=$$d validate; done

lint: ## tflint and actionlint
	tflint --init >/dev/null
	@for d in $(TF_DIRS) terraform/modules/*; do tflint --chdir=$$d --config=$(CURDIR)/.tflint.hcl --format compact; done
	actionlint

scan: ## checkov over Terraform
	checkov --config-file .checkov.yaml

k8s: ## helm lint and kubeconform
	helm lint kubernetes/argocd/root
	helm lint kubernetes/apps/api -f kubernetes/apps/api/values-dev.yaml
	helm lint kubernetes/platform/karpenter/nodepools -f kubernetes/platform/karpenter/nodepools/values-dev.yaml
	scripts/validate-manifests.sh

api: ## test and build the API
	cd apps/api && go vet ./... && golangci-lint run ./... && go test -race ./... && CGO_ENABLED=0 go build ./...

frontend: ## test and build the frontend
	cd apps/frontend && npm ci && npm run lint && npm test && npm run build

check: fmt validate lint scan k8s api frontend ## Everything
