
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  -- Every SKU has exactly one current cost version.
select sku from "qafila"."silver"."product_cost_history"
group by sku
having count(*) filter (where is_current) <> 1
  
  
      
    ) dbt_internal_test