
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

with all_values as (

    select
        reason as value_field,
        count(*) as n_records

    from "qafila"."silver"."supplier_prices_checked"
    group by reason

)

select *
from all_values
where value_field not in (
    'unknown_sku','invalid_cost'
)



  
  
      
    ) dbt_internal_test