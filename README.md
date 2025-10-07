# Materialize dbt Project Example

This project demonstrates how to properly configure and organize a dbt project for [Materialize](https://materialize.com), showcasing best practices for building real-time data objects.

## Overview

This example teaches you how to:
- Configure dbt models as views, indexed views, and materialized views in Materialize
- Set up sources using Materialize's load generators
- Create sinks to export data to Kafka
- Organize your project with proper layer separation (staging, intermediate, marts)
- Use dbt selectors for controlled deployment
- Implement comprehensive testing strategies

The project uses an auction house scenario to illustrate these concepts, implementing flipper detection, health monitoring, and suspicious activity alerts as practical examples of real-time data transformations.

## Materialize Concepts Demonstrated

This project showcases key Materialize features with practical examples:

- **[Views](MATERIALIZE_CONCEPTS.md#views)** - Staging and intermediate transformations without storage overhead
- **[Indexes](MATERIALIZE_CONCEPTS.md#indexes)** - Query optimization on intermediate views
- **[Materialized Views](MATERIALIZE_CONCEPTS.md#materialized-views)** - Real-time maintained analytics in the marts layer
- **[Sources](MATERIALIZE_CONCEPTS.md#sources)** - Load generator creating streaming auction data
- **[Sinks](MATERIALIZE_CONCEPTS.md#sinks)** - Kafka exports with DEBEZIUM envelope format

📚 **See [MATERIALIZE_CONCEPTS.md](MATERIALIZE_CONCEPTS.md) for detailed explanations and examples of each concept.**

## Quick Start with Docker

### Prerequisites
- Docker and Docker Compose
- dbt-materialize adapter: `pip install dbt-materialize`
- psql (PostgreSQL client) for running setup scripts

### Docker Setup

1. **Start the services:**
   ```bash
   docker compose up -d
   ```
   
   This starts:
   - Materialize (port 6875)
   - Redpanda/Kafka (port 9092)
   - Redpanda Console (port 8080 - web UI for Kafka)

2. **Run the setup script:**
   ```bash
   psql "postgresql://materialize@localhost:6875/materialize" -f scripts/setup_materialize.sql
   ```
   
   Or use the automated setup:
   ```bash
   ./scripts/setup.sh
   ```

3. **Install dbt dependencies:**
   ```bash
   pip install dbt-materialize
   dbt deps
   ```

4. **Test the connection:**
   ```bash
   dbt debug --profiles-dir . --profile materialize_auction_house
   ```

5. **Run the project:**
   ```bash
   dbt seed --profiles-dir . --profile materialize_auction_house                        # Load known flippers
   dbt run --selector sources_only --profiles-dir . --profile materialize_auction_house     # Create sources (first time only)
   dbt run --profiles-dir . --profile materialize_auction_house                            # Create all models except sources
   dbt test --profiles-dir . --profile materialize_auction_house                           # Run tests
   ```
   
   Or use selectors:
   ```bash
   dbt run --selector sources_only --profiles-dir . --profile materialize_auction_house      # Only create sources
   dbt run --profiles-dir . --profile materialize_auction_house                             # Default: all models except sources/sinks
   dbt run --selector transformations --profiles-dir . --profile materialize_auction_house  # Only staging, intermediate, marts
   dbt run --selector sinks_only --profiles-dir . --profile materialize_auction_house       # Only create sinks
   ```

### Monitoring

- **Materialize Console:** `psql "postgresql://materialize@localhost:6875/materialize"`
- **Redpanda Console:** http://localhost:8080 (view topics and messages)
- **View streaming data:**
  ```sql
  -- Connect to Materialize
  psql "postgresql://materialize@localhost:6875/materialize"
  
  -- Watch flippers in real-time
  COPY (SUBSCRIBE (SELECT * FROM public_marts.fct_auction_flippers)) TO STDOUT;
  ```

### Cleanup

```bash
docker compose down -v  # Stop and remove containers/volumes
```

## Cloud/Production Setup

For Materialize Cloud or production deployments:

1. **Update profiles.yml** with your Materialize Cloud credentials:
   ```yaml
   materialize_auction_house:
     outputs:
       production:
         type: materialize
         host: <your-host>.aws.materialize.cloud
         port: 6875
         user: <your-email>
         pass: <your-app-password>
         database: materialize
         schema: public
         cluster: production_cluster
         sslmode: require
   ```

2. **Initialize Materialize resources:**
   ```sql
   -- Create clusters
   CREATE CLUSTER sources REPLICAS (r1 (SIZE = '25cc'));
   CREATE CLUSTER compute REPLICAS (r1 (SIZE = '25cc'));
   CREATE CLUSTER sinks REPLICAS (r1 (SIZE = '25cc'));
   
   -- Create source
   CREATE SOURCE auction_house
     IN CLUSTER sources
     FROM LOAD GENERATOR AUCTION
     (TICK INTERVAL '1s', AS OF 100000)
     FOR ALL TABLES;
   
   -- Configure Kafka for production
   CREATE SECRET kafka_password AS 'your-password';
   CREATE CONNECTION kafka_connection TO KAFKA (
     BROKER 'your-kafka-broker:9092',
     SASL MECHANISMS = 'PLAIN',
     SASL USERNAME = 'user',
     SASL PASSWORD = SECRET kafka_password
   );
   ```

3. **Run dbt against production:**
   ```bash
   dbt run --target production --profiles-dir . --profile materialize_auction_house
   dbt test --target production --profiles-dir . --profile materialize_auction_house
   ```

## Usage

### Run all models
```bash
dbt run --profiles-dir . --profile materialize_auction_house
```

### Run specific model layers
```bash
dbt run --select staging --profiles-dir . --profile materialize_auction_house     # Raw data preparation
dbt run --select intermediate --profiles-dir . --profile materialize_auction_house # Business logic
dbt run --select marts --profiles-dir . --profile materialize_auction_house       # Final analytics
```

### Run tests
```bash
dbt test --profiles-dir . --profile materialize_auction_house
```

### Load seed data
```bash
dbt seed --profiles-dir . --profile materialize_auction_house
```

### Generate and view documentation
```bash
# Generate documentation
dbt docs generate --profiles-dir . --profile materialize_auction_house

# Serve documentation locally
dbt docs serve --profiles-dir . --profile materialize_auction_house --port 8080
```

The documentation includes:
- **Model Lineage**: Visual DAG showing data flow from sources to sinks
- **Model Documentation**: Descriptions and column-level details for all models
- **Test Results**: Data quality test results integrated into the docs
- **Schema Information**: Complete catalog of tables, views, and materialized views

## Project Structure

- **Sources**: Materialize source definitions (load generators, Kafka, etc.)
- **Staging**: Views that clean and standardize raw source data
- **Intermediate**: Views implementing core business logic (winning bids, flip detection)
- **Marts**: Materialized views and indexed views for analytics
- **Sinks**: Kafka exports for real-time data streaming

## Selectors

The project includes pre-configured selectors for common deployment patterns:

- `default`: Runs all transformations (excludes sources and sinks)
- `sources_only`: Only create/update sources
- `sinks_only`: Only create/update sinks
- `transformations`: Only staging, intermediate, and marts
- `staging_only`: Only staging models
- `intermediate_only`: Only intermediate models
- `marts_only`: Only mart models
- `flippers`: Models related to flipper detection
- `metrics`: Models related to metrics and monitoring
- `no_sinks`: Everything except sinks

Example usage:
```bash
# Initial setup - create sources first
dbt run --selector sources_only --profiles-dir . --profile materialize_auction_house

# Regular deployment - transformations only
dbt run --selector transformations --profiles-dir . --profile materialize_auction_house

# Update only metrics models
dbt run --selector metrics --profiles-dir . --profile materialize_auction_house
```

## Key Features Demonstrated

### Materialize-Specific Features
- **Views**: Efficient transformations without persistence ([staging/](models/staging/), [intermediate/](models/intermediate/))
- **Materialized Views**: Incrementally maintained results ([marts/](models/marts/))
- **Indexes**: Multi-column indexes for join optimization ([int_winning_bids](models/intermediate/int_winning_bids.sql))
- **Sources**: Load generator for streaming data ([auction_load_generator](models/sources/auction_load_generator.sql))
- **Sinks**: Real-time Kafka exports with DEBEZIUM envelope ([sinks/](models/sinks/))
- **Clusters**: Workload isolation (sources, compute, sinks)

### Real-time Analytics
- Live auction status tracking with window functions
- Continuous flipper detection using self-joins
- Streaming health metrics with hourly aggregations
- Real-time suspicious activity alerts with pattern matching

### dbt Best Practices
- Modular model architecture with clear layer separation
- 54 data quality tests for comprehensive validation
- Full documentation with column descriptions
- Environment-specific configurations (dev/staging/production)

## Customization

Key variables in `dbt_project.yml`:
- `flipper_threshold_days`: Days to consider for flip detection (default: 8)
- `min_profit_margin`: Minimum profit margin for flippers (default: 0.20)
- Cluster names for sources, compute, and sinks

## Resources

### Materialize Documentation
- [Materialize Docs Home](https://materialize.com/docs/)
- [Views](https://materialize.com/docs/sql/create-view/)
- [Materialized Views](https://materialize.com/docs/sql/create-materialized-view/)
- [Sources](https://materialize.com/docs/sql/create-source/)
- [Sinks](https://materialize.com/docs/sql/create-sink/)
- [Indexes](https://materialize.com/docs/sql/create-index/)
- [Clusters](https://materialize.com/docs/sql/create-cluster/)

### dbt Resources
- [dbt-materialize Adapter](https://github.com/MaterializeInc/dbt-materialize)
- [dbt Documentation](https://docs.getdbt.com/)
- [dbt Best Practices](https://docs.getdbt.com/best-practices)

### Community
- [Materialize Community Slack](https://materialize.com/community/)
- [Materialize Blog](https://materialize.com/blog/)
- [GitHub Discussions](https://github.com/MaterializeInc/materialize/discussions)

## License

This example project is provided as-is for demonstration purposes.