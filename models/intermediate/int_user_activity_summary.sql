{{
  config(
    materialized='view'
  )
}}

-- Simplified version for the basic auction load generator schema
WITH bid_activity AS (
    SELECT
        buyer_account_id AS account_id,
        COUNT(DISTINCT auction_id) AS auctions_bid_on,
        COUNT(*) AS total_bids,
        AVG(bid_amount) AS avg_bid_amount,
        MAX(bid_amount) AS max_bid_amount,
        MIN(bid_time) AS first_bid_time,
        MAX(bid_time) AS last_bid_time
    FROM {{ ref('stg_bids') }}
    GROUP BY buyer_account_id
),

won_auctions AS (
    SELECT
        winner_account_id AS account_id,
        COUNT(*) AS auctions_won,
        SUM(winning_amount) AS total_spent,
        AVG(winning_amount) AS avg_winning_amount
    FROM {{ ref('int_winning_bids') }}
    GROUP BY winner_account_id
),

sold_auctions AS (
    SELECT
        seller_account_id AS account_id,
        COUNT(*) AS auctions_sold,
        SUM(winning_amount) AS total_revenue,
        AVG(winning_amount) AS avg_sale_price
    FROM {{ ref('int_winning_bids') }}
    GROUP BY seller_account_id
)

SELECT
    COALESCE(b.account_id, w.account_id, s.account_id) AS account_id,
    COALESCE(b.auctions_bid_on, 0) AS auctions_bid_on,
    COALESCE(b.total_bids, 0) AS total_bids,
    COALESCE(b.avg_bid_amount, 0) AS avg_bid_amount,
    COALESCE(b.max_bid_amount, 0) AS max_bid_amount,
    COALESCE(w.auctions_won, 0) AS auctions_won,
    COALESCE(w.total_spent, 0) AS total_spent,
    COALESCE(w.avg_winning_amount, 0) AS avg_winning_amount,
    COALESCE(s.auctions_sold, 0) AS auctions_sold,
    COALESCE(s.total_revenue, 0) AS total_revenue,
    COALESCE(s.avg_sale_price, 0) AS avg_sale_price,
    b.first_bid_time,
    b.last_bid_time,
    CASE 
        WHEN w.auctions_won > 0 AND b.total_bids > 0 
        THEN w.auctions_won::FLOAT / b.total_bids 
        ELSE 0 
    END AS win_rate
FROM bid_activity b
FULL OUTER JOIN won_auctions w ON b.account_id = w.account_id
FULL OUTER JOIN sold_auctions s ON COALESCE(b.account_id, w.account_id) = s.account_id