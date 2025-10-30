{{
  config(
    materialized='sink',
    cluster=var("sink_cluster")
  )
}}

FROM {{ ref('realtime_suspicious_activity') }}
INTO KAFKA CONNECTION kafka_connection (
    TOPIC 'suspicious-activity-alerts'
)
FORMAT JSON
ENVELOPE DEBEZIUM