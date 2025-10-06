{{
  config(
    materialized='sink',
    cluster='{{ var("sink_cluster") }}'
  )
}}

CREATE SINK {{ this }}
IN CLUSTER sinks
FROM {{ ref('fct_auction_flippers') }}
INTO KAFKA CONNECTION kafka_connection (
    TOPIC 'auction-flippers'
)
FORMAT JSON
ENVELOPE DEBEZIUM