-- Test that a numeric column only increases over time
-- Useful for counters, running totals, or cumulative metrics
{% test monotonic_increase(model, column_name, timestamp_column='metric_hour', group_by=none) %}

with ordered_data as (
    select
        {{ column_name }} as current_value,
        lag({{ column_name }}) over (
            {% if group_by %}
            partition by {{ group_by }}
            {% endif %}
            order by {{ timestamp_column }}
        ) as previous_value
    from {{ model }}
)

select *
from ordered_data
where current_value < previous_value
  and previous_value is not null

{% endtest %}