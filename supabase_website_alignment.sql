-- Safe additive alignment with the website reference schema.
-- Run this in Supabase SQL editor. It only adds missing columns/indexes.

alter table public.products
add column if not exists currency text default 'EGP',
add column if not exists stock_qty integer default 1,
add column if not exists slug text,
add column if not exists validated boolean default true,
add column if not exists listing_details jsonb default '{}'::jsonb;

create index if not exists products_slug_idx
  on public.products (slug);

create index if not exists products_validated_idx
  on public.products (validated);

alter table public.orders
add column if not exists customer_email text,
add column if not exists company text,
add column if not exists address_line2 text,
add column if not exists currency text default 'EGP',
add column if not exists subtotal_price numeric,
add column if not exists shipping_price numeric default 0,
add column if not exists stripe_checkout_session_id text,
add column if not exists stripe_payment_intent_id text;

alter table public.order_items
add column if not exists product_name text,
add column if not exists image_url text,
add column if not exists line_total_price numeric,
add column if not exists currency text default 'EGP';

alter table public.profiles
add column if not exists first_name text,
add column if not exists last_name text,
add column if not exists shop_name text,
add column if not exists bio text,
add column if not exists avatar_url text,
add column if not exists location text,
add column if not exists phone text;

-- Backfill website-style product/order snapshot fields for existing rows.
update public.products
set currency = coalesce(currency, 'EGP'),
    stock_qty = coalesce(stock_qty, 1),
    validated = coalesce(validated, true),
    listing_details = coalesce(listing_details, '{}'::jsonb)
where currency is null
   or stock_qty is null
   or validated is null
   or listing_details is null;

update public.orders
set currency = coalesce(currency, 'EGP'),
    subtotal_price = coalesce(subtotal_price, total_price),
    shipping_price = coalesce(shipping_price, 0)
where currency is null
   or subtotal_price is null
   or shipping_price is null;

update public.order_items oi
set product_name = coalesce(oi.product_name, p.title),
    image_url = coalesce(oi.image_url, p.main_image_url),
    line_total_price = coalesce(oi.line_total_price, oi.price * oi.quantity),
    currency = coalesce(oi.currency, p.currency, 'EGP')
from public.products p
where oi.product_id = p.id
  and (
    oi.product_name is null
    or oi.image_url is null
    or oi.line_total_price is null
    or oi.currency is null
  );
