{{ config(materialized='incremental', unique_key='LISTING_ID') }}


SELECT * FROM  {{ source('staging', 'listings') }}

{% if is_incremental() %}
    -- Re-read a 3-day lookback window instead of only rows newer than the max,
    -- so late-arriving rows aren't skipped; unique_key merges the overlap, so no duplicates.
    WHERE CREATED_AT > (SELECT DATEADD(day, -3, COALESCE(MAX(CREATED_AT), '1900-01-01'::TIMESTAMP)) FROM {{ this }})
{% endif %}
