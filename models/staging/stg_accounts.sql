{{
  config(
    materialized='view'
  )
}}

SELECT
    id AS account_id,
    org_id AS organization_id,
    balance
FROM {{ source('auction', 'accounts') }}