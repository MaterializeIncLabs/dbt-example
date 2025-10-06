{{
  config(
    materialized='view'
  )
}}

SELECT
    id AS user_id,
    org_id AS organization_id,
    name AS user_name
FROM {{ source('auction', 'users') }}