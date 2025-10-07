-- Test for statistical outliers using z-score method
-- Useful for detecting anomalies in streaming data
{% test outlier_detection(model, column_name, z_threshold=3) %}

with stats as (
    select
        avg({{ column_name }}) as mean_value,
        stddev({{ column_name }}) as std_value
    from {{ model }}
),

z_scores as (
    select
        *,
        abs(({{ column_name }} - stats.mean_value) / nullif(stats.std_value, 0)) as z_score
    from {{ model }}
    cross join stats
)

select *
from z_scores
where z_score > {{ z_threshold }}

{% endtest %}