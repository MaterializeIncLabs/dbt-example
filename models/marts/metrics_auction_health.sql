{{
  config(
    materialized='materializedview'
  )
}}

WITH hourly_metrics AS (
    SELECT
        DATE_TRUNC('hour', bid_time) AS metric_hour,
        DATE(bid_time) AS metric_date,
        COUNT(DISTINCT auction_id) AS active_auctions,
        COUNT(DISTINCT buyer_account_id) AS active_bidders,
        COUNT(*) AS total_bids,
        AVG(bid_amount) AS avg_bid_amount,
        MAX(bid_amount) AS max_bid_amount,
        MIN(bid_amount) AS min_bid_amount,
        STDDEV(bid_amount) AS bid_amount_stddev
    FROM {{ ref('stg_bids') }}
    GROUP BY DATE_TRUNC('hour', bid_time), DATE(bid_time)
),

auction_completion AS (
    SELECT
        DATE(auction_end_time) AS metric_date,
        COUNT(*) AS auctions_completed,
        AVG(winning_amount) AS avg_final_price,
        SUM(winning_amount) AS total_gmv
    FROM {{ ref('int_winning_bids') }}
    GROUP BY DATE(auction_end_time)
)

SELECT
    hm.metric_hour,
    hm.metric_date,
    hm.active_auctions,
    hm.active_bidders,
    hm.total_bids,
    hm.avg_bid_amount,
    hm.max_bid_amount,
    hm.min_bid_amount,
    hm.bid_amount_stddev,
    COALESCE(ac.auctions_completed, 0) AS auctions_completed,
    COALESCE(ac.avg_final_price, 0) AS avg_final_price,
    COALESCE(ac.total_gmv, 0) AS daily_gmv,
    CASE
        WHEN hm.active_bidders > 0 
        THEN hm.total_bids::FLOAT / hm.active_bidders 
        ELSE 0 
    END AS bids_per_bidder,
    CASE
        WHEN hm.active_auctions > 0 
        THEN hm.total_bids::FLOAT / hm.active_auctions 
        ELSE 0 
    END AS bids_per_auction
FROM hourly_metrics hm
LEFT JOIN auction_completion ac ON hm.metric_date = ac.metric_date
ORDER BY hm.metric_hour DESC