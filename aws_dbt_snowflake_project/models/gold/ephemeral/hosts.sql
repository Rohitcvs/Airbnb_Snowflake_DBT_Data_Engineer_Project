{{
  config(
    materialized = 'ephemeral',
    )
}}

WITH hosts AS 
(
    -- One row per entity: the OBT has one row per booking, so the same
    -- host/listing appears many times. The snapshot needs a unique key.
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
