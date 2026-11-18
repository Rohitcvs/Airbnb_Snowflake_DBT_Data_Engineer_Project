{{
  config(
    materialized = 'ephemeral',
    )
}}

WITH listings AS 
(
    -- One row per entity: the OBT has one row per booking, so the same
    -- host/listing appears many times. The snapshot needs a unique key.
    SELECT DISTINCT
        LISTING_ID,
        PROPERTY_TYPE,
        ROOM_TYPE,
        CITY,
        COUNTRY,
        PRICE_PER_NIGHT_TAG,
        LISTING_CREATED_AT
    FROM 
        {{ ref('obt') }}
)
SELECT * FROM listings
