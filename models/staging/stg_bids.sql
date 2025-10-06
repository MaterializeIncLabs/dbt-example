{{
  config(
    materialized='view'
  )
}}

SELECT
    id AS bid_id,
    buyer AS buyer_account_id,
    auction_id,
    amount AS bid_amount,
    bid_time
FROM {{ source('auction', 'bids') }}
WHERE amount > 0