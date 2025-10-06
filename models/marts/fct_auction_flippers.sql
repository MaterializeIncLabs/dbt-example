{{
  config(
    materialized='materializedview',
    indexes=[
      {'columns': ['account_id']},
      {'columns': ['total_flips']}
    ]
  )
}}

WITH flipper_summary AS (
    SELECT
        account_id,
        COUNT(*) AS total_flips,
        AVG(EXTRACT(EPOCH FROM time_to_flip) / 86400.0) AS avg_days_to_flip,
        MIN(purchase_time) AS first_flip_purchase,
        MAX(resale_end_time) AS last_flip_resale,
        STRING_AGG(DISTINCT item, ', ' ORDER BY item) AS items_flipped
    FROM {{ ref('int_auction_flips') }}
    GROUP BY account_id
),

account_details AS (
    SELECT
        a.account_id,
        a.organization_id,
        a.balance,
        o.organization_name
    FROM {{ ref('stg_accounts') }} a
    LEFT JOIN {{ ref('stg_organizations') }} o ON a.organization_id = o.organization_id
)

SELECT
    f.account_id,
    ad.organization_name,
    ad.balance AS current_balance,
    f.total_flips,
    f.avg_days_to_flip,
    f.first_flip_purchase,
    f.last_flip_resale,
    f.items_flipped,
    CASE
        WHEN f.total_flips >= 10 THEN 'high_volume_flipper'
        WHEN f.total_flips >= 5 THEN 'moderate_flipper'
        WHEN f.total_flips >= 2 THEN 'casual_flipper'
        ELSE 'occasional_flipper'
    END AS flipper_category
FROM flipper_summary f
JOIN account_details ad ON f.account_id = ad.account_id
ORDER BY f.total_flips DESC