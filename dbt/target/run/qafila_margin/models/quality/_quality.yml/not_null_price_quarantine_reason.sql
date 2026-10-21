
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select reason
from "qafila"."quality"."price_quarantine"
where reason is null



  
  
      
    ) dbt_internal_test