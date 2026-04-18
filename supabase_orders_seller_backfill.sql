alter table public.orders
add column if not exists seller_id uuid references auth.users (id) on delete set null;

create index if not exists orders_seller_id_idx
  on public.orders (seller_id);

with seller_links as (
  select
    oi.order_id,
    min(oi.seller_id) as seller_id,
    count(distinct oi.seller_id) as seller_count
  from public.order_items oi
  where oi.seller_id is not null
  group by oi.order_id
)
update public.orders o
set seller_id = sl.seller_id
from seller_links sl
where o.id = sl.order_id
  and sl.seller_count = 1
  and (o.seller_id is null or o.seller_id <> sl.seller_id);
