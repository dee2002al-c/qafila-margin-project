-- margin = costed revenue - cost, and uncosted lines never exceed lines.
select * from "qafila"."gold"."weekly_margin"
where abs(costed_revenue_sar - cost_sar - margin_sar) > 0.011 or uncosted_lines > lines