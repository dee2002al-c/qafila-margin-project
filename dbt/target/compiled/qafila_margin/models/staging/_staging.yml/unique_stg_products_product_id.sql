
    
    

select
    product_id as unique_field,
    count(*) as n_records

from "qafila"."staging"."stg_products"
where product_id is not null
group by product_id
having count(*) > 1


