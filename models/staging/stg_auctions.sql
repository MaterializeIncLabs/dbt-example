{{
  config(
    materialized='view'
  )
}}

SELECT
    id AS auction_id,
    seller AS seller_account_id,
    item,
    end_time
FROM {{ source('auction', 'auctions') }}
WHERE item IS NOT NULL