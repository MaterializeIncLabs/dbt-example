.PHONY: help setup test test-workflows test-deployment test-all clean docker-up docker-down

# Default target
help:
	@echo "Available targets:"
	@echo "  make setup              - Set up local Docker environment"
	@echo "  make test               - Run all tests"
	@echo "  make test-workflows     - Validate GitHub Actions workflows"
	@echo "  make test-deployment    - Test blue/green deployment (requires Docker)"
	@echo "  make docker-up          - Start Docker containers"
	@echo "  make docker-down        - Stop Docker containers"
	@echo "  make clean              - Clean up deployment artifacts"
	@echo ""
	@echo "Quick start:"
	@echo "  make docker-up && make test"

# Start Docker environment
docker-up:
	@echo "Starting Docker containers..."
	docker-compose up -d
	@echo "Waiting for services to be ready..."
	@./scripts/setup.sh

# Stop Docker environment
docker-down:
	@echo "Stopping Docker containers..."
	docker-compose down

# Set up environment (alias for docker-up)
setup: docker-up

# Run workflow validation tests
test-workflows:
	@echo "Running workflow validation tests..."
	@./scripts/test_workflows.sh

# Run blue/green deployment integration tests
test-deployment:
	@echo "Running blue/green deployment integration tests..."
	@./scripts/test_blue_green_deployment.sh

# Run all tests
test: test-workflows test-deployment

# Alias for test
test-all: test

# Clean up deployment artifacts and test data
clean:
	@echo "Cleaning up deployment artifacts..."
	@rm -rf target/
	@rm -rf dbt_packages/
	@rm -rf logs/
	@echo "Cleaning up Docker containers..."
	@docker-compose down -v 2>/dev/null || true
	@echo "Clean complete!"

# Install dbt dependencies
deps:
	@echo "Installing dbt dependencies..."
	dbt deps --profiles-dir . --profile materialize_auction_house

# Run dbt tests (data quality tests)
test-dbt:
	@echo "Running dbt data quality tests..."
	dbt test --profiles-dir . --profile materialize_auction_house --target dev
