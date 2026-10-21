
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select unit_cost_sar
from "qafila"."silver"."product_cost_history"
where unit_cost_sar is null



  
  
      
    ) dbt_internal_test