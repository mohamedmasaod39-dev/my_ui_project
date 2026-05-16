-- Fix for Buyers being unable to update stock_qty during checkout
-- Supabase Row Level Security (RLS) silently blocks updates if a policy isn't defined.
-- This policy allows any logged-in user to update the products table, 
-- which enables the mobile app to decrease the stock quantity upon purchase.

alter table public.products enable row level security;

drop policy if exists "Authenticated users can update products" on public.products;
create policy "Authenticated users can update products"
on public.products
for update
using (auth.role() = 'authenticated')
with check (auth.role() = 'authenticated');
