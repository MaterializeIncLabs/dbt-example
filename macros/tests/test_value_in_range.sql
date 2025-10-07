-- Test that values fall within an expected range
-- Useful for validating metrics, percentages, or scores
{% test value_in_range(model, column_name, min_value=0, max_value=100) %}

select *
from {{ model }}
where {{ column_name }} < {{ min_value }}
   or {{ column_name }} > {{ max_value }}

{% endtest %}