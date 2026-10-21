
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select city
from "qafila"."gold"."weekly_margin"
where city is null



  
  
      
    ) dbt_internal_test