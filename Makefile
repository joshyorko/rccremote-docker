.PHONY: help build clean test
.DEFAULT_GOAL := help

# Color output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[0;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

# Default configuration
PROJECT_NAME := rccremote-docker
SERVER_NAME ?= rccremote.local
NAMESPACE ?= rccremote
REPLICAS ?= 3
ENVIRONMENT ?= development

# Docker registry configuration
DOCKER_REGISTRY ?= ghcr.io
DOCKER_REPO ?= yorko-io/rccremote-docker
IMAGE_TAG ?= latest
FULL_IMAGE_NAME := $(DOCKER_REGISTRY)/$(DOCKER_REPO):$(IMAGE_TAG)

# Docker Compose file paths
COMPOSE_DEV := docker-compose/docker-compose.development.yml
COMPOSE_PROD := docker-compose/docker-compose.production.yml
COMPOSE_CF := docker-compose/docker-compose.cloudflare.yml

# Paths
CERTS_PATH := ./certs
DATA_PATH := ./data
SCRIPTS_PATH := ./scripts
K8S_PATH := ./k8s

##@ General

help: ## Display this help message
	@echo "$(BLUE)╔═══════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(BLUE)║       RCC Remote Docker - Deployment Manager            ║$(NC)"
	@echo "$(BLUE)╚═══════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf "Usage:\n  make $(YELLOW)<target>$(NC)\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  $(GREEN)%-25s$(NC) %s\n", $$1, $$2 } /^##@/ { printf "\n$(BLUE)%s$(NC)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

version: ## Show version information
	@echo "$(GREEN)Project:$(NC) $(PROJECT_NAME)"
	@echo "$(GREEN)RCC Version:$(NC) 17.28.4"
	@echo "$(GREEN)RCC Remote Version:$(NC) 17.18.0"

##@ Docker Build & Setup

build: ## Build Docker images
	@echo "$(BLUE)Building Docker images...$(NC)"
	docker build -f Dockerfile-rcc -t rccremote:latest .
	@echo "$(GREEN)✓ Build complete$(NC)"

build-tag: ## Build and tag for registry
	@echo "$(BLUE)Building and tagging image: $(FULL_IMAGE_NAME)$(NC)"
	docker build -f Dockerfile-rcc -t rccremote:latest -t $(FULL_IMAGE_NAME) .
	@echo "$(GREEN)✓ Build and tag complete$(NC)"

push: build-tag ## Build, tag and push Docker image to registry
	@echo "$(BLUE)Pushing image to registry: $(FULL_IMAGE_NAME)$(NC)"
	docker push $(FULL_IMAGE_NAME)
	@echo "$(GREEN)✓ Image pushed successfully$(NC)"
	@echo "$(YELLOW)Image: $(FULL_IMAGE_NAME)$(NC)"

pull: ## Pull Docker image from registry
	@echo "$(BLUE)Pulling image: $(FULL_IMAGE_NAME)$(NC)"
	docker pull $(FULL_IMAGE_NAME)
	@echo "$(GREEN)✓ Image pulled successfully$(NC)"

registry-login: ## Login to Docker registry (GitHub Container Registry)
	@echo "$(BLUE)Logging into $(DOCKER_REGISTRY)...$(NC)"
	@echo "$(YELLOW)You will need a GitHub Personal Access Token with packages:write permission$(NC)"
	@echo "$(YELLOW)Create one at: https://github.com/settings/tokens/new?scopes=write:packages$(NC)"
	@echo ""
	@read -p "GitHub Username: " username; \
	echo "GitHub Token (input hidden): "; \
	read -s token; \
	echo "$$token" | docker login $(DOCKER_REGISTRY) -u "$$username" --password-stdin
	@echo "$(GREEN)✓ Login successful$(NC)"

build-dev: ## Build for development
	@echo "$(BLUE)Building development images...$(NC)"
	docker compose -f $(COMPOSE_DEV) build
	@echo "$(GREEN)✓ Development build complete$(NC)"

build-prod: ## Build for production
	@echo "$(BLUE)Building production images...$(NC)"
	docker compose -f $(COMPOSE_PROD) build
	@echo "$(GREEN)✓ Production build complete$(NC)"

##@ Certificate Management

certs-generate: ## Generate self-signed certificates
	@echo "$(BLUE)Generating self-signed certificates...$(NC)"
	$(SCRIPTS_PATH)/create-selfsigned-cert.sh
	@echo "$(GREEN)✓ Self-signed certificates generated$(NC)"

certs-signed: ## Generate CA-signed certificates
	@echo "$(BLUE)Generating CA-signed certificates...$(NC)"
	$(SCRIPTS_PATH)/create-signed-cert.sh
	@echo "$(GREEN)✓ CA-signed certificates generated$(NC)"

certs-clean: ## Remove generated certificates
	@echo "$(YELLOW)Removing certificates...$(NC)"
	rm -rf $(CERTS_PATH)/*
	@echo "$(GREEN)✓ Certificates cleaned$(NC)"

certs-manage: ## Interactive certificate management
	@$(SCRIPTS_PATH)/cert-management.sh

##@ Development Deployment

dev-up: ## Start development environment
	@echo "$(BLUE)Starting development environment...$(NC)"
	docker compose -f $(COMPOSE_DEV) up -d
	@echo "$(GREEN)✓ Development environment started on port 8443$(NC)"
	@echo "$(YELLOW)Access at: https://$(SERVER_NAME):8443$(NC)"

dev-down: ## Stop development environment
	@echo "$(YELLOW)Stopping development environment...$(NC)"
	docker compose -f $(COMPOSE_DEV) down
	@echo "$(GREEN)✓ Development environment stopped$(NC)"

dev-logs: ## Show development logs
	docker compose -f $(COMPOSE_DEV) logs -f

dev-restart: ## Restart development environment
	@$(MAKE) dev-down
	@$(MAKE) dev-up

dev-clean: ## Clean development environment (including volumes)
	@echo "$(RED)Cleaning development environment and volumes...$(NC)"
	docker compose -f $(COMPOSE_DEV) down -v
	@echo "$(GREEN)✓ Development environment cleaned$(NC)"

dev-shell-rccremote: ## Shell into development rccremote container
	docker exec -it rccremote-dev bash

dev-shell-nginx: ## Shell into development nginx container
	docker exec -it rccremote-nginx-dev sh

##@ Production Deployment

prod-up: ## Start production environment (requires SERVER_NAME)
	@if [ -z "$(SERVER_NAME)" ] || [ "$(SERVER_NAME)" = "rccremote.local" ]; then \
		echo "$(RED)ERROR: Please set SERVER_NAME for production deployment$(NC)"; \
		echo "Usage: make prod-up SERVER_NAME=your-domain.com"; \
		exit 1; \
	fi
	@echo "$(BLUE)Starting production environment for $(SERVER_NAME)...$(NC)"
	SERVER_NAME=$(SERVER_NAME) docker compose -f $(COMPOSE_PROD) up -d
	@echo "$(GREEN)✓ Production environment started on port 443$(NC)"
	@echo "$(YELLOW)Access at: https://$(SERVER_NAME)$(NC)"

prod-down: ## Stop production environment
	@echo "$(YELLOW)Stopping production environment...$(NC)"
	docker compose -f $(COMPOSE_PROD) down
	@echo "$(GREEN)✓ Production environment stopped$(NC)"

prod-logs: ## Show production logs
	docker compose -f $(COMPOSE_PROD) logs -f

prod-restart: ## Restart production environment
	@$(MAKE) prod-down
	@$(MAKE) prod-up SERVER_NAME=$(SERVER_NAME)

prod-clean: ## Clean production environment (including volumes)
	@echo "$(RED)Cleaning production environment and volumes...$(NC)"
	docker compose -f $(COMPOSE_PROD) down -v
	@echo "$(GREEN)✓ Production environment cleaned$(NC)"

prod-shell-rccremote: ## Shell into production rccremote container
	docker exec -it rccremote-prod bash

prod-shell-nginx: ## Shell into production nginx container
	docker exec -it rccremote-nginx-prod sh

##@ Cloudflare Tunnel Deployment

cf-create: ## Create Cloudflare tunnel programmatically (requires --hostname)
	@if [ -z "$(HOSTNAME)" ]; then \
		echo "$(RED)ERROR: Please specify HOSTNAME$(NC)"; \
		echo "Usage: make cf-create HOSTNAME=rccremote.example.com"; \
		echo ""; \
		echo "Optional parameters:"; \
		echo "  TUNNEL_NAME=name    (default: rccremote)"; \
		echo "  AUTO_DEPLOY=true    (auto-deploy after creation)"; \
		exit 1; \
	fi
	@echo "$(BLUE)Creating Cloudflare tunnel...$(NC)"
	@chmod +x $(SCRIPTS_PATH)/create-cloudflare-tunnel.sh
	@$(SCRIPTS_PATH)/create-cloudflare-tunnel.sh \
		--hostname $(HOSTNAME) \
		$(if $(TUNNEL_NAME),--tunnel-name $(TUNNEL_NAME),) \
		$(if $(AUTO_DEPLOY),--auto-deploy,)

cf-create-deploy: ## Create tunnel and auto-deploy
	@$(MAKE) cf-create HOSTNAME=$(HOSTNAME) AUTO_DEPLOY=true

cf-tunnel-list: ## List all Cloudflare tunnels
	@echo "$(BLUE)Cloudflare Tunnels:$(NC)"
	@command -v cloudflared >/dev/null 2>&1 && cloudflared tunnel list || echo "$(RED)cloudflared not installed$(NC)"

cf-tunnel-info: ## Show tunnel information (requires TUNNEL_NAME)
	@if [ -z "$(TUNNEL_NAME)" ]; then \
		echo "$(RED)ERROR: Please specify TUNNEL_NAME$(NC)"; \
		echo "Usage: make cf-tunnel-info TUNNEL_NAME=rccremote"; \
		exit 1; \
	fi
	@echo "$(BLUE)Tunnel Information:$(NC)"
	@cloudflared tunnel info $(TUNNEL_NAME)

cf-tunnel-delete: ## Delete a Cloudflare tunnel (requires TUNNEL_NAME)
	@if [ -z "$(TUNNEL_NAME)" ]; then \
		echo "$(RED)ERROR: Please specify TUNNEL_NAME$(NC)"; \
		echo "Usage: make cf-tunnel-delete TUNNEL_NAME=rccremote"; \
		exit 1; \
	fi
	@echo "$(RED)WARNING: This will permanently delete the tunnel!$(NC)"
	@read -p "Are you sure? (yes/no): " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		cloudflared tunnel delete $(TUNNEL_NAME); \
		echo "$(GREEN)✓ Tunnel deleted$(NC)"; \
	else \
		echo "$(YELLOW)Cancelled$(NC)"; \
	fi

cf-up: ## Start Cloudflare tunnel deployment (requires CF_TUNNEL_TOKEN)
	@if [ -z "$(CF_TUNNEL_TOKEN)" ]; then \
		echo "$(RED)ERROR: Please set CF_TUNNEL_TOKEN environment variable$(NC)"; \
		echo "Usage: make cf-up CF_TUNNEL_TOKEN=your_token"; \
		echo ""; \
		echo "Or create a tunnel first: make cf-create HOSTNAME=rccremote.example.com"; \
		exit 1; \
	fi
	@echo "$(BLUE)Starting Cloudflare tunnel deployment...$(NC)"
	CF_TUNNEL_TOKEN=$(CF_TUNNEL_TOKEN) docker compose -f $(COMPOSE_CF) up -d
	@echo "$(GREEN)✓ Cloudflare tunnel started$(NC)"

cf-down: ## Stop Cloudflare tunnel deployment
	@echo "$(YELLOW)Stopping Cloudflare tunnel...$(NC)"
	docker compose -f $(COMPOSE_CF) down
	@echo "$(GREEN)✓ Cloudflare tunnel stopped$(NC)"

cf-logs: ## Show Cloudflare tunnel logs
	docker compose -f $(COMPOSE_CF) logs -f

cf-restart: ## Restart Cloudflare tunnel
	@$(MAKE) cf-down
	@$(MAKE) cf-up CF_TUNNEL_TOKEN=$(CF_TUNNEL_TOKEN)

cf-clean: ## Clean Cloudflare deployment (including volumes)
	@echo "$(RED)Cleaning Cloudflare deployment and volumes...$(NC)"
	docker compose -f $(COMPOSE_CF) down -v
	@echo "$(GREEN)✓ Cloudflare deployment cleaned$(NC)"

##@ Kubernetes Deployment

k8s-deploy: ## Deploy to Kubernetes
	@echo "$(BLUE)Deploying to Kubernetes (namespace: $(NAMESPACE), replicas: $(REPLICAS))...$(NC)"
	$(SCRIPTS_PATH)/deploy-k8s.sh --namespace $(NAMESPACE) --replicas $(REPLICAS)
	@echo "$(GREEN)✓ Kubernetes deployment complete$(NC)"

k8s-apply: ## Apply Kubernetes manifests manually
	@echo "$(BLUE)Applying Kubernetes manifests...$(NC)"
	kubectl apply -f $(K8S_PATH)/namespace.yaml
	kubectl apply -f $(K8S_PATH)/configmap.yaml
	kubectl apply -f $(K8S_PATH)/secret.yaml
	kubectl apply -f $(K8S_PATH)/persistent-volume.yaml
	kubectl apply -f $(K8S_PATH)/deployment.yaml
	kubectl apply -f $(K8S_PATH)/service.yaml
	kubectl apply -f $(K8S_PATH)/health-check.yaml
	@echo "$(GREEN)✓ Manifests applied$(NC)"

k8s-apply-config: ## Apply only ConfigMaps (useful for updates)
	@echo "$(BLUE)Applying ConfigMaps...$(NC)"
	kubectl apply -f $(K8S_PATH)/configmap.yaml
	@echo "$(GREEN)✓ ConfigMaps applied$(NC)"

k8s-restart: ## Restart deployment (rollout restart)
	@echo "$(BLUE)Restarting deployment...$(NC)"
	kubectl rollout restart deployment/rccremote -n $(NAMESPACE)
	kubectl rollout status deployment/rccremote -n $(NAMESPACE)
	@echo "$(GREEN)✓ Deployment restarted$(NC)"

k8s-fix-config: ## Fix ConfigMaps and restart deployment
	@echo "$(BLUE)Fixing ConfigMaps and restarting...$(NC)"
	@$(MAKE) k8s-apply-config
	@$(MAKE) k8s-restart
	@echo "$(GREEN)✓ Configuration fixed and deployment restarted$(NC)"

k8s-delete: ## Delete Kubernetes resources
	@echo "$(YELLOW)Deleting Kubernetes resources...$(NC)"
	kubectl delete -f $(K8S_PATH)/ --ignore-not-found=true
	@echo "$(GREEN)✓ Resources deleted$(NC)"

k8s-uninstall: ## Uninstall and cleanup Kubernetes deployment (including namespace)
	@echo "$(RED)WARNING: This will delete the namespace and all resources!$(NC)"
	@read -p "Are you sure you want to uninstall? (yes/no): " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		echo "$(YELLOW)Deleting all resources in namespace $(NAMESPACE)...$(NC)"; \
		kubectl delete namespace $(NAMESPACE) --ignore-not-found=true; \
		echo "$(GREEN)✓ Namespace $(NAMESPACE) and all resources deleted$(NC)"; \
	else \
		echo "$(YELLOW)Cancelled$(NC)"; \
	fi

k8s-status: ## Show Kubernetes deployment status
	@echo "$(BLUE)Kubernetes Status:$(NC)"
	@kubectl get pods -n $(NAMESPACE) -l app=rccremote
	@kubectl get svc -n $(NAMESPACE)
	@kubectl get hpa -n $(NAMESPACE)

k8s-logs: ## Show Kubernetes pod logs
	kubectl logs -n $(NAMESPACE) -l app=rccremote -c rccremote --tail=100 -f

k8s-shell: ## Shell into Kubernetes pod
	kubectl exec -it -n $(NAMESPACE) $$(kubectl get pod -n $(NAMESPACE) -l app=rccremote -o jsonpath='{.items[0].metadata.name}') -c rccremote -- bash

k8s-port-forward: ## Port forward to Kubernetes service
	@echo "$(BLUE)Port forwarding to localhost:8443...$(NC)"
	kubectl port-forward -n $(NAMESPACE) svc/rccremote 8443:443

k8s-describe: ## Describe Kubernetes resources
	kubectl describe deployment -n $(NAMESPACE) rccremote
	kubectl describe svc -n $(NAMESPACE) rccremote

k8s-events: ## Show Kubernetes events
	kubectl get events -n $(NAMESPACE) --sort-by='.lastTimestamp'

##@ Testing & Health Checks

test-health: ## Run health check
	@echo "$(BLUE)Running health check...$(NC)"
	$(SCRIPTS_PATH)/health-check.sh

test-connectivity: ## Test RCC connectivity
	@echo "$(BLUE)Testing RCC connectivity...$(NC)"
	$(SCRIPTS_PATH)/test-connectivity.sh

test-integration: ## Run integration tests
	@echo "$(BLUE)Running integration tests...$(NC)"
	@cd tests/integration && bash test_complete_workflow.sh

test-docker: ## Test Docker deployment
	@echo "$(BLUE)Testing Docker deployment...$(NC)"
	@cd tests/integration && bash test_docker_deployment.sh

test-k8s: ## Test Kubernetes deployment
	@echo "$(BLUE)Testing Kubernetes deployment...$(NC)"
	@cd tests/integration && bash test_k8s_deployment.sh

test-rcc: ## Test RCC connectivity
	@echo "$(BLUE)Testing RCC connectivity...$(NC)"
	@cd tests/integration && bash test_rcc_connectivity.sh

test-all: ## Run all tests
	@$(MAKE) test-integration
	@$(MAKE) test-health

##@ Client Configuration

client-configure: ## Configure RCC client
	@echo "$(BLUE)Configuring RCC client...$(NC)"
	$(SCRIPTS_PATH)/configure-rcc-profile.sh
	@echo "$(GREEN)✓ RCC client configured$(NC)"
	@echo "$(YELLOW)Don't forget to set RCC_REMOTE_ORIGIN:$(NC)"
	@echo "export RCC_REMOTE_ORIGIN=https://$(SERVER_NAME):8443"

client-setup-dev: ## Setup client for development
	@$(MAKE) client-configure
	@echo "export RCC_REMOTE_ORIGIN=https://$(SERVER_NAME):8443" >> ~/.zshrc
	@echo "$(GREEN)✓ Development client setup complete$(NC)"

client-setup-prod: ## Setup client for production
	@if [ -z "$(SERVER_NAME)" ] || [ "$(SERVER_NAME)" = "rccremote.local" ]; then \
		echo "$(RED)ERROR: Please set SERVER_NAME$(NC)"; \
		exit 1; \
	fi
	@$(MAKE) client-configure
	@echo "export RCC_REMOTE_ORIGIN=https://$(SERVER_NAME)" >> ~/.zshrc
	@echo "$(GREEN)✓ Production client setup complete$(NC)"

##@ Maintenance

logs: ## Show logs based on environment
	@if docker ps | grep -q rccremote-dev; then \
		$(MAKE) dev-logs; \
	elif docker ps | grep -q rccremote-prod; then \
		$(MAKE) prod-logs; \
	elif docker ps | grep -q rccremote-cf; then \
		$(MAKE) cf-logs; \
	else \
		echo "$(YELLOW)No running containers found$(NC)"; \
	fi

ps: ## Show running containers/pods
	@echo "$(BLUE)Docker Containers:$(NC)"
	@docker ps --filter "name=rccremote" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
	@echo ""
	@echo "$(BLUE)Kubernetes Pods:$(NC)"
	@kubectl get pods -n $(NAMESPACE) 2>/dev/null || echo "No Kubernetes deployment found"

clean: ## Clean all deployments
	@echo "$(RED)Cleaning all deployments...$(NC)"
	-$(MAKE) dev-clean 2>/dev/null
	-$(MAKE) prod-clean 2>/dev/null
	-$(MAKE) cf-clean 2>/dev/null
	@echo "$(GREEN)✓ All Docker deployments cleaned$(NC)"

clean-all: clean ## Clean everything including images and volumes
	@echo "$(RED)Removing all Docker images and volumes...$(NC)"
	docker rmi rccremote:latest 2>/dev/null || true
	docker volume prune -f
	@echo "$(GREEN)✓ Complete cleanup done$(NC)"

reset: clean-all build ## Complete reset - clean and rebuild
	@echo "$(GREEN)✓ Complete reset finished$(NC)"

##@ Quick Start Commands

quick-dev: certs-generate dev-up ## Quick start development (generate certs + start)
	@echo "$(GREEN)✓ Development environment ready!$(NC)"
	@echo "$(YELLOW)Next steps:$(NC)"
	@echo "1. Configure your RCC client: make client-configure"
	@echo "2. Set environment: export RCC_REMOTE_ORIGIN=https://$(SERVER_NAME):8443"
	@echo "3. Test: rcc holotree catalogs"

quick-prod: ## Quick start production (requires SERVER_NAME)
	@if [ ! -f "$(CERTS_PATH)/server.crt" ]; then \
		echo "$(RED)ERROR: Production certificates not found$(NC)"; \
		echo "Run: make certs-signed"; \
		exit 1; \
	fi
	@$(MAKE) prod-up SERVER_NAME=$(SERVER_NAME)
	@echo "$(GREEN)✓ Production environment ready!$(NC)"

quick-cf: ## Quick start Cloudflare (create tunnel + deploy, requires HOSTNAME)
	@if [ -z "$(HOSTNAME)" ]; then \
		echo "$(RED)ERROR: Please specify HOSTNAME$(NC)"; \
		echo "Usage: make quick-cf HOSTNAME=rccremote.example.com"; \
		exit 1; \
	fi
	@$(MAKE) cf-create-deploy HOSTNAME=$(HOSTNAME)
	@echo "$(GREEN)✓ Cloudflare tunnel ready!$(NC)"

quick-k8s: build k8s-deploy ## Quick start Kubernetes
	@echo "$(GREEN)✓ Kubernetes deployment ready!$(NC)"

uninstall: ## Uninstall deployment (auto-detects environment)
	@echo "$(BLUE)Detecting active deployments...$(NC)"
	@if kubectl get namespace $(NAMESPACE) >/dev/null 2>&1; then \
		echo "$(YELLOW)Found Kubernetes deployment in namespace: $(NAMESPACE)$(NC)"; \
		$(MAKE) k8s-uninstall; \
	elif docker ps | grep -q rccremote-dev; then \
		echo "$(YELLOW)Found development Docker deployment$(NC)"; \
		$(MAKE) dev-clean; \
	elif docker ps | grep -q rccremote-prod; then \
		echo "$(YELLOW)Found production Docker deployment$(NC)"; \
		$(MAKE) prod-clean; \
	elif docker ps | grep -q rccremote-cf; then \
		echo "$(YELLOW)Found Cloudflare Docker deployment$(NC)"; \
		$(MAKE) cf-clean; \
	else \
		echo "$(YELLOW)No active deployments found$(NC)"; \
	fi

##@ Documentation

docs: ## Open documentation
	@echo "$(BLUE)Opening documentation...$(NC)"
	@echo "Available docs:"
	@echo "  - README.md"
	@echo "  - docs/QUICKSTART.md"
	@echo "  - docs/deployment-guide.md"
	@echo "  - docs/ARCHITECTURE.md"
	@echo "  - docs/kubernetes-setup.md"
	@echo "  - docs/cloudflare-tunnel-guide.md"

docs-quickstart: ## View quickstart guide
	@cat docs/QUICKSTART.md

docs-architecture: ## View architecture docs
	@cat docs/ARCHITECTURE.md

##@ Utilities

validate: ## Validate configuration files
	@echo "$(BLUE)Validating configuration...$(NC)"
	@docker compose -f $(COMPOSE_DEV) config > /dev/null && echo "$(GREEN)✓ Development config valid$(NC)"
	@docker compose -f $(COMPOSE_PROD) config > /dev/null && echo "$(GREEN)✓ Production config valid$(NC)"
	@docker compose -f $(COMPOSE_CF) config > /dev/null && echo "$(GREEN)✓ Cloudflare config valid$(NC)"

setup-samples: ## Copy sample robots to data directory
	@echo "$(BLUE)Setting up sample robots...$(NC)"
	@mkdir -p $(DATA_PATH)/robots
	@cp -r $(DATA_PATH)/robots-samples/* $(DATA_PATH)/robots/
	@echo "$(GREEN)✓ Sample robots copied$(NC)"

shell: ## Interactive shell based on running container
	@if docker ps | grep -q rccremote-dev; then \
		$(MAKE) dev-shell-rccremote; \
	elif docker ps | grep -q rccremote-prod; then \
		$(MAKE) prod-shell-rccremote; \
	else \
		echo "$(YELLOW)No running containers found$(NC)"; \
	fi

update-scripts: ## Make all scripts executable
	@echo "$(BLUE)Updating script permissions...$(NC)"
	@chmod +x $(SCRIPTS_PATH)/*.sh
	@echo "$(GREEN)✓ Scripts updated$(NC)"

##@ Environment Info

env-info: ## Show environment information
	@echo "$(BLUE)Environment Information:$(NC)"
	@echo "$(GREEN)PROJECT_NAME:$(NC) $(PROJECT_NAME)"
	@echo "$(GREEN)SERVER_NAME:$(NC) $(SERVER_NAME)"
	@echo "$(GREEN)NAMESPACE:$(NC) $(NAMESPACE)"
	@echo "$(GREEN)REPLICAS:$(NC) $(REPLICAS)"
	@echo "$(GREEN)ENVIRONMENT:$(NC) $(ENVIRONMENT)"
	@echo ""
	@echo "$(BLUE)Docker:$(NC)"
	@docker --version
	@docker compose version
	@echo ""
	@echo "$(BLUE)Kubernetes:$(NC)"
	@kubectl version --client --short 2>/dev/null || echo "kubectl not installed"
	@echo ""
	@echo "$(BLUE)Available Compose Files:$(NC)"
	@ls -1 docker-compose/*.yml

env-check: ## Check prerequisites
	@echo "$(BLUE)Checking prerequisites...$(NC)"
	@command -v docker >/dev/null 2>&1 && echo "$(GREEN)✓ Docker installed$(NC)" || echo "$(RED)✗ Docker not found$(NC)"
	@command -v docker compose >/dev/null 2>&1 && echo "$(GREEN)✓ Docker Compose installed$(NC)" || echo "$(RED)✗ Docker Compose not found$(NC)"
	@command -v kubectl >/dev/null 2>&1 && echo "$(GREEN)✓ kubectl installed$(NC)" || echo "$(YELLOW)⚠ kubectl not found (optional for k8s)$(NC)"
	@command -v openssl >/dev/null 2>&1 && echo "$(GREEN)✓ OpenSSL installed$(NC)" || echo "$(RED)✗ OpenSSL not found$(NC)"
	@command -v rcc >/dev/null 2>&1 && echo "$(GREEN)✓ RCC installed$(NC)" || echo "$(YELLOW)⚠ RCC not found (install from https://sema4.ai)$(NC)"

##@ Advanced

monitor: ## Monitor running containers
	@watch -n 2 'docker ps --filter "name=rccremote" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'

backup: ## Backup data volumes
	@echo "$(BLUE)Backing up data volumes...$(NC)"
	@mkdir -p backups
	@tar -czf backups/robots-$(shell date +%Y%m%d-%H%M%S).tar.gz -C $(DATA_PATH) robots
	@echo "$(GREEN)✓ Backup complete$(NC)"

restore: ## Restore data from backup (set BACKUP_FILE)
	@if [ -z "$(BACKUP_FILE)" ]; then \
		echo "$(RED)ERROR: Please set BACKUP_FILE$(NC)"; \
		echo "Usage: make restore BACKUP_FILE=backups/robots-xxx.tar.gz"; \
		exit 1; \
	fi
	@echo "$(BLUE)Restoring from $(BACKUP_FILE)...$(NC)"
	@tar -xzf $(BACKUP_FILE) -C $(DATA_PATH)
	@echo "$(GREEN)✓ Restore complete$(NC)"
