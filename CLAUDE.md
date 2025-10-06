# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Type

This is a Materialize-specific dbt project demonstrating real-time streaming analytics using the auction house example from Materialize's quickstart.

## Common Commands

### dbt Commands
All commands require: `--profiles-dir . --profile materialize_auction_house`

- `dbt run` - Execute all models
- `dbt test` - Run all tests  
- `dbt build` - Run models and tests
- `dbt compile` - Compile SQL without executing
- `dbt debug` - Test Materialize connection
- `dbt deps` - Install package dependencies (dbt-utils)
- `dbt seed` - Load seed data (known_flippers.csv)
- `dbt docs generate` - Generate documentation with model lineage and catalog
- `dbt docs serve --port 8080` - Serve documentation locally (includes visual DAG)

### Development Commands
Add `--profiles-dir . --profile materialize_auction_house` to all commands:

- `dbt run --selector sources_only` - Create sources (first time or after drop)
- `dbt run` - Run default selector (all transformations, no sources/sinks)
- `dbt run --selector transformations` - Run staging, intermediate, and marts
- `dbt run --selector flippers` - Run flipper-related models
- `dbt run --selector metrics` - Run metrics and monitoring models
- `dbt run --select +model_name` - Run model and its upstream dependencies
- `dbt run --select model_name+` - Run model and its downstream dependencies
- `dbt test --store-failures` - Store test failures for analysis
- `dbt run --target staging` - Run against staging environment
- `dbt run --target production` - Run against production environment

## Project Structure

```
materialize_auction_house/
├── dbt_project.yml          # Main configuration with cluster settings
├── profiles.yml             # Connection profiles for dev/staging/prod
├── packages.yml             # dbt-utils dependency
├── models/
│   ├── sources/            # Source definitions (sources cluster)
│   │   └── *.sql          # CREATE SOURCE statements
│   ├── staging/            # Views over raw sources (compute cluster)
│   │   ├── _sources.yml    # Source table references
│   │   └── stg_*.sql       # Staging transformations
│   ├── intermediate/       # Business logic views (compute cluster)
│   │   └── int_*.sql       # Intermediate transformations
│   ├── marts/              # Final analytics (compute cluster)
│   │   └── fct_*, metrics_* # Materialized views and indexed views
│   └── sinks/              # Kafka sinks (sinks cluster)
│       └── sink_*.sql      # Export to Kafka topics
├── selectors.yml          # Pre-configured model selectors
└── seeds/
    └── known_flippers.csv  # Manual flipper list

```

## Materialize-Specific Features Used

### Clusters
- `sources` - For source data ingestion
- `compute` - For transformations and analytics
- `sinks` - For data export to Kafka

### Materializations
- **Views**: Staging and intermediate models (no storage, query shorthand)
- **Indexed Views**: Marts with indexes for performance
- **Materialized Views**: Real-time maintained results for critical metrics
- **Sinks**: Export to Kafka topics with DEBEZIUM envelope format

### Key Functions
- Window functions with streaming semantics
- LATERAL joins for Top-K queries
- Streaming aggregations and joins

## Data Flow

1. **Sources**: Created via dbt with `materialized='source'` (run with `--selector sources_only`)
   - `auction_load_generator`: Creates subsources for accounts, auctions, bids, users, organizations
2. **Staging**: Clean and standardize raw data from subsources
3. **Intermediate**: Calculate winning bids, detect flips, summarize activity
4. **Marts**: 
   - `fct_auction_flippers`: Flipper detection and categorization
   - `metrics_auction_health`: Platform health metrics
   - `realtime_suspicious_activity`: Real-time alerts
5. **Sinks**: Export to Kafka for downstream consumption (run with `--selector sinks_only`)

## Key Business Logic

- **Flipper Detection**: Items bought and resold within 8 days (configurable)
- **Profit Margin Threshold**: 20% minimum for flipper classification
- **Categories**: high_volume_flipper, moderate_flipper, casual_flipper, occasional_flipper
- **Suspicious Activity**: Rapid bidding (>10 bids/minute) or high-margin flips (>50%)

## Testing Strategy

- Source data validation (not_null, unique, relationships)
- Business rule validation (expression_is_true)
- Accepted values for categorical fields
- Referential integrity across models

## Documentation

The project includes comprehensive dbt docs with:

- **Model Descriptions**: Each staging, intermediate, and mart model has detailed descriptions
- **Column Documentation**: All key columns documented with business context
- **Data Lineage**: Visual DAG showing complete data flow from sources to sinks
- **Test Integration**: Data quality test results displayed inline with model documentation
- **Schema Catalog**: Complete catalog of all database objects with metadata

Access via: `dbt docs generate && dbt docs serve --port 8080`