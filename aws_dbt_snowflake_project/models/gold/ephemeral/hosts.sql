{{
  config(
    materialized = 'ephemeral',
    )
}}

WITH hosts AS 
(
    -- obt has one row per booking; DISTINCT gives one row per key for the snapshot
    SELECT DISTINCT
        HOST_ID,
        HOST_NAME,
        HOST_SINCE,
        IS_SUPERHOST,
        RESPONSE_RATE_QUALITY,
        HOST_CREATED_AT
    FROM 
        {{ ref('obt') }}
)
SELECT * FROM hosts
