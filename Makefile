.PHONY: help build run stop logs test clean deploy

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## Build the Docker image
	docker-compose build

run: ## Run the collector locally
	docker-compose up -d
	@echo "Collector running at:"
	@echo "  OTLP gRPC: localhost:4317"
	@echo "  OTLP HTTP: localhost:4318"
	@echo "  Metrics:   localhost:8888"
	@echo "  Health:    localhost:13133"

stop: ## Stop the collector
	docker-compose down

logs: ## View collector logs
	docker-compose logs -f otel-collector

test: ## Test the collector health
	@echo "Testing health endpoint..."
	@curl -f http://localhost:13133/ && echo "✓ Collector is healthy" || echo "✗ Collector is not responding"
	@echo ""
	@echo "Checking metrics endpoint..."
	@curl -s http://localhost:8888/metrics | head -n 5 && echo "✓ Metrics available" || echo "✗ Metrics not available"

clean: ## Clean up containers and images
	docker-compose down -v
	docker rmi otel-tail-sampling-otel-collector || true

deploy: ## Deploy to Azure (requires Azure CLI and logged in)
	@echo "Deploying to Azure App Service..."
	@./scripts/deploy.sh

dev: ## Run with Jaeger for local development
	docker-compose --profile dev up -d
	@echo "Jaeger UI available at: http://localhost:16686"
