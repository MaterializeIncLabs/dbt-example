-- Test referential integrity across multiple levels
-- Useful for ensuring data consistency in complex joins
{% test referential_integrity_cascade(model, column_name, parent_model, parent_column, grandparent_model=none, grandparent_column=none) %}

with validation as (
    select distinct m.{{ column_name }}
    from {{ model }} m
    left join {{ parent_model }} p
        on m.{{ column_name }} = p.{{ parent_column }}
    {% if grandparent_model %}
    left join {{ grandparent_model }} gp
        on p.{{ parent_column }} = gp.{{ grandparent_column }}
    {% endif %}
    where p.{{ parent_column }} is null
    {% if grandparent_model %}
       or gp.{{ grandparent_column }} is null
    {% endif %}
)

select * from validation

{% endtest %}