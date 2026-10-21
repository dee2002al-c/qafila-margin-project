-- Grain: one row per order line (order_id, line_no).
select
    order_id,
    line_no,
    product_id,
    quantity,
    unit_price,
    discount
from {{ source('raw', 'order_items') }}
