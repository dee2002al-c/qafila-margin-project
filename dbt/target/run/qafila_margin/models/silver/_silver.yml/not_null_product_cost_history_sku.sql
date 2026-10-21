
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select sku
from "qafila"."silver"."product_cost_history"
where sku is null



  
  
      
    ) dbt_internal_test