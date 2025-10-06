{{
  config(
    materialized='view'
  )
}}

WITH purchases AS (
    SELECT
        winner_account_id AS account_id,
        item,
        winning_amount AS purchase_price,
        auction_end_time AS purchase_time,
        auction_id
    FROM {{ ref('int_winning_bids') }}
),

resales AS (
    SELECT
        a.seller_account_id AS account_id,
        a.item,
        a.end_time AS resale_end_time,
        a.auction_id
    FROM {{ ref('stg_auctions') }} a
)

SELECT
    p.account_id,
    p.item,
    p.purchase_price,
    p.purchase_time,
    r.resale_end_time,
    r.resale_end_time - p.purchase_time AS time_to_flip,
    p.auction_id AS purchase_auction_id,
    r.auction_id AS resale_auction_id
FROM purchases p
JOIN resales r
    ON p.account_id = r.account_id
    AND p.item = r.item
    AND r.resale_end_time > p.purchase_time
    AND r.resale_end_time <= p.purchase_time + INTERVAL '{{ var("flipper_threshold_days") }} days'
WHERE p.purchase_price > 0