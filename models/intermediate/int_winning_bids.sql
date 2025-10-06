{{
  config(
    materialized='view',
    indexes=[
      {'columns': ['auction_id']},
      {'columns': ['winner_account_id']},
      {'columns': ['seller_account_id']}
    ]
  )
}}

WITH ranked_bids AS (
    SELECT
        b.auction_id,
        b.buyer_account_id,
        b.bid_amount,
        b.bid_time,
        a.end_time,
        a.item,
        a.seller_account_id,
        ROW_NUMBER() OVER (
            PARTITION BY b.auction_id 
            ORDER BY b.bid_amount DESC, b.bid_time ASC
        ) AS bid_rank
    FROM {{ ref('stg_bids') }} b
    JOIN {{ ref('stg_auctions') }} a
        ON b.auction_id = a.auction_id
    -- Only consider auctions that have ended
    WHERE b.bid_time <= a.end_time
)

SELECT
    auction_id,
    buyer_account_id AS winner_account_id,
    seller_account_id,
    item,
    bid_amount AS winning_amount,
    bid_time AS winning_bid_time,
    end_time AS auction_end_time
FROM ranked_bids
WHERE bid_rank = 1