-- Grain: one row per store.
select store_id, city
from {{ source('raw', 'stores') }}
