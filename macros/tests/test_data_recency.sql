-- Test that ensures data has been updated recently
-- Useful for monitoring streaming data pipelines
{% test data_recency(model, column_name, interval='1 hour') %}

select count(*)
from {{ model }}
where {{ column_name }} < (SELECT MAX({{ column_name }}) FROM {{ model }}) - interval '{{ interval }}'
having count(*) = (SELECT count(*) FROM {{ model }})

{% endtest %}