
  
  create view "qafila"."staging"."stg_stores__dbt_tmp" as (
    -- Grain: one row per store.
select store_id, city
from "qafila"."raw"."stores"
  );
