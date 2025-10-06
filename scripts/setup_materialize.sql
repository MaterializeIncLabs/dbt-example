-- Setup script for Materialize
-- Run this after starting the Docker containers

-- Drop and recreate clusters for different workloads
DROP CLUSTER IF EXISTS sources CASCADE;
DROP CLUSTER IF EXISTS compute CASCADE;
DROP CLUSTER IF EXISTS sinks CASCADE;

CREATE CLUSTER sources REPLICAS (r1 (SIZE = '25cc'));
CREATE CLUSTER compute REPLICAS (r1 (SIZE = '25cc')); 
CREATE CLUSTER sinks REPLICAS (r1 (SIZE = '25cc'));

-- Set default cluster
SET CLUSTER = compute;

-- Drop and recreate source
DROP SOURCE IF EXISTS auction_house CASCADE;

CREATE SOURCE auction_house
  IN CLUSTER sources
  FROM LOAD GENERATOR AUCTION
  (TICK INTERVAL '1s', AS OF 100000)
  FOR ALL TABLES;

-- Create Kafka connection for sinks (without SSL for local development)
DROP CONNECTION IF EXISTS kafka_connection CASCADE;

CREATE CONNECTION kafka_connection TO KAFKA (
  BROKER 'redpanda:9092',
  SECURITY PROTOCOL = 'PLAINTEXT'
);

-- Create Schema Registry connection for AVRO format
DROP CONNECTION IF EXISTS csr_connection CASCADE;

CREATE CONNECTION csr_connection TO CONFLUENT SCHEMA REGISTRY (
  URL 'http://redpanda:8081'
);

-- Create schemas for organization
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS intermediate;
CREATE SCHEMA IF NOT EXISTS marts;