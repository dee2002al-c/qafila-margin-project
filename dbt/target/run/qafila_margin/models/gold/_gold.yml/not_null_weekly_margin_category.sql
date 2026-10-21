
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select category
from "qafila"."gold"."weekly_margin"
where category is null



  
  
      
    ) dbt_internal_test