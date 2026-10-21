
    
    

with all_values as (

    select
        reason as value_field,
        count(*) as n_records

    from "qafila"."quality"."price_quarantine"
    group by reason

)

select *
from all_values
where value_field not in (
    'unknown_sku','invalid_cost'
)


