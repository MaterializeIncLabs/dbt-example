{{
  config(
    materialized='sink',
    cluster='{{ var("sink_cluster") }}'
  )
}}

CREATE SINK {{ this }}
IN CLUSTER sinks
FROM {{ ref('realtime_suspicious_activity') }}
INTO KAFKA CONNECTION kafka_connection (
    TOPIC 'suspicious-activity-alerts'
)
FORMAT JSON
ENVELOPE DEBEZIUM