{{
  config(
    materialized='sink',
    cluster=var("sink_cluster")
  )
}}

FROM {{ ref('fct_auction_flippers') }}
INTO KAFKA CONNECTION kafka_connection (
    TOPIC 'auction-flippers'
)
FORMAT JSON
ENVELOPE DEBEZIUM