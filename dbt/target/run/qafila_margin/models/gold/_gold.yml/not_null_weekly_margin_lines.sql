
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select lines
from "qafila"."gold"."weekly_margin"
where lines is null



  
  
      
    ) dbt_internal_test