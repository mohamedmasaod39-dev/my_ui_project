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

alter table public.orders enable row level security;

drop policy if exists "Buyers can view own orders" on public.orders;
create policy "Buyers can view own orders"
on public.orders
for select
using (auth.uid() = buyer_id);

drop policy if exists "Buyers can create own orders" on public.orders;
create policy "Buyers can create own orders"
on public.orders
for insert
with check (auth.uid() = buyer_id);

drop policy if exists "Buyers can update own orders" on public.orders;
create policy "Buyers can update own orders"
on public.orders
for update
using (auth.uid() = buyer_id)
with check (auth.uid() = buyer_id);

drop policy if exists "Sellers can view assigned orders" on public.orders;
create policy "Sellers can view assigned orders"
on public.orders
for select
using (auth.uid() = seller_id);

drop policy if exists "Sellers can update assigned orders" on public.orders;
create policy "Sellers can update assigned orders"
on public.orders
for update
using (auth.uid() = seller_id)
with check (auth.uid() = seller_id);

drop policy if exists "Admins can view all orders" on public.orders;
create policy "Admins can view all orders"
on public.orders
for select
using (
  exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.role = 'admin'
  )
);

drop policy if exists "Admins can update all orders" on public.orders;
create policy "Admins can update all orders"
on public.orders
for update
using (
  exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.role = 'admin'
  )
)
with check (
  exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.role = 'admin'
  )
);
