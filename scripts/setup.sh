#!/bin/bash

echo "Starting Docker containers..."
docker-compose up -d

echo "Waiting for services to be ready..."
sleep 10

echo "Checking Materialize connection..."
until psql "postgresql://materialize@localhost:6875/materialize" -c "SELECT 1" > /dev/null 2>&1; do
    echo "Waiting for Materialize to be ready..."
    sleep 2
done

echo "Checking Redpanda connection..."
until docker exec redpanda rpk cluster info > /dev/null 2>&1; do
    echo "Waiting for Redpanda to be ready..."
    sleep 2
done

echo "Setting up Materialize clusters and sources..."
psql "postgresql://materialize@localhost:6875/materialize" -f scripts/setup_materialize.sql

echo "Creating Kafka topics..."
docker exec redpanda rpk topic create \
    auction-flippers \
    suspicious-activity-alerts \
    auction-health-metrics \
    --brokers localhost:9092

echo "Setup complete! You can now run dbt commands."
echo ""
echo "Useful URLs:"
echo "  - Materialize: postgresql://materialize@localhost:6875/materialize"
echo "  - Redpanda Console: http://localhost:8080"
echo ""
echo "To test the dbt project:"
echo "  dbt debug"
echo "  dbt deps"
echo "  dbt seed"
echo "  dbt run"
echo "  dbt test"