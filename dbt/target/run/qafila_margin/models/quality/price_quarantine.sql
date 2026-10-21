
    

    create  table
      "qafila"."quality"."price_quarantine__dbt_tmp"
  
    
    as (
      -- Grain: one row per rejected supplier row.
select source_file, sku, valid_from, raw_cost, reason
from "qafila"."silver"."supplier_prices_checked"
where reason is not null
    );
    
  