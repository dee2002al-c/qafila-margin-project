
    
    

select
    sku as unique_field,
    count(*) as n_records

from "qafila"."staging"."stg_products"
where sku is not null
group by sku
having count(*) > 1


