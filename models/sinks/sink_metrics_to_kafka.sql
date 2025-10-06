{{
  config(
    materialized='sink',
    cluster='{{ var("sink_cluster") }}'
  )
}}

CREATE SINK {{ this }}
IN CLUSTER sinks
FROM {{ ref('metrics_auction_health') }}
INTO KAFKA CONNECTION kafka_connection (
    TOPIC 'auction-health-metrics'
)
FORMAT JSON
ENVELOPE DEBEZIUM