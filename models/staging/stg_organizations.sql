{{
  config(
    materialized='view'
  )
}}

SELECT
    id AS organization_id,
    name AS organization_name
FROM {{ source('auction', 'organizations') }}