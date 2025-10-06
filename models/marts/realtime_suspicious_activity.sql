{{
  config(
    materialized='materializedview',
    cluster='compute'
  )
}}

WITH recent_flips AS (
    SELECT
        account_id,
        item,
        time_to_flip,
        purchase_time,
        resale_end_time
    FROM {{ ref('int_auction_flips') }}
),

rapid_bidding AS (
    SELECT
        buyer_account_id AS account_id,
        COUNT(*) AS total_bids
    FROM {{ ref('stg_bids') }}
    GROUP BY buyer_account_id
    HAVING COUNT(*) > 100
),

suspicious_accounts AS (
    SELECT DISTINCT
        COALESCE(rf.account_id, rb.account_id) AS account_id,
        CASE
            WHEN rf.account_id IS NOT NULL AND rb.account_id IS NOT NULL THEN 'rapid_flipper_and_bidder'
            WHEN rf.account_id IS NOT NULL THEN 'rapid_flipper'
            WHEN rb.account_id IS NOT NULL THEN 'excessive_bidder'
        END AS alert_type,
        COALESCE(rb.total_bids, 0) AS total_bids
    FROM recent_flips rf
    FULL OUTER JOIN rapid_bidding rb ON rf.account_id = rb.account_id
)

SELECT
    sa.account_id,
    a.balance,
    sa.alert_type,
    sa.total_bids
FROM suspicious_accounts sa
JOIN {{ ref('stg_accounts') }} a ON sa.account_id = a.account_id