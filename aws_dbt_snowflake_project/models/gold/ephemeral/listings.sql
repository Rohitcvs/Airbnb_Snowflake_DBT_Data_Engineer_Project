{{
  config(
    materialized = 'ephemeral',
    )
}}

WITH listings AS 
(
    -- obt has one row per booking; DISTINCT gives one row per key for the snapshot
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
