-- This model creates the auction house source from the load generator
-- Run with: dbt run --select tag:source
{{ config(
    materialized='source',
    cluster='sources',
    tags=['source']
) }}

CREATE SOURCE {{ this }}
IN CLUSTER sources
FROM LOAD GENERATOR AUCTION (TICK INTERVAL '1s', AS OF 100000)
FOR ALL TABLES