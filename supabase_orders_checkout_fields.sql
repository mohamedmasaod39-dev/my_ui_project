alter table public.orders
add column if not exists customer_name text,
add column if not exists city text,
add column if not exists state text,
add column if not exists zipcode text,
add column if not exists shipping_same_as_billing boolean default false,
add column if not exists card_holder_name text,
add column if not exists card_last4 text,
add column if not exists card_expiry text;
