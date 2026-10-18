{% macro trimmer(column_name) %}
    UPPER(TRIM({{ column_name }}))
{% endmacro %}
