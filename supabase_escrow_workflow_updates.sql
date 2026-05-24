-- ============================================================
-- ESCROW WORKFLOW: Restrict Seller Order Update Permission
-- Run this in Supabase Dashboard → SQL Editor
-- ============================================================

-- 1. DROP the seller update policy on orders
--    (Sellers must NEVER be able to change order status or details.
--     All order updates are handled exclusively by admins.)
DROP POLICY IF EXISTS "Sellers can update assigned orders" ON public.orders;

-- 2. Ensure admins can still update all order fields (already exists,
--    recreated here as a safety net in case it was dropped)
DROP POLICY IF EXISTS "Admins can update all orders" ON public.orders;
CREATE POLICY "Admins can update all orders"
ON public.orders
FOR UPDATE
USING (
    EXISTS (
        SELECT 1 FROM profiles
        WHERE profiles.id = auth.uid()
        AND profiles.role = 'admin'
    )
);

-- 3. Ensure buyers can only update their OWN orders (for cancellation only)
--    Sellers have no update access at all.
DROP POLICY IF EXISTS "Buyers can update own orders" ON public.orders;
CREATE POLICY "Buyers can update own orders"
ON public.orders
FOR UPDATE
USING (auth.uid() = buyer_id)
WITH CHECK (auth.uid() = buyer_id);

-- 4. Ensure escrow_confirmations: buyers & sellers can upsert ONLY their own row
--    (already created in supabase_migration.sql — recreated here as safety net)
DROP POLICY IF EXISTS "Users can upsert their own escrow confirmation" ON public.escrow_confirmations;
CREATE POLICY "Users can upsert their own escrow confirmation"
ON public.escrow_confirmations
FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- 5. Ensure admins can read ALL escrow confirmations (for the admin dashboard)
DROP POLICY IF EXISTS "Admins can view all escrow confirmations" ON public.escrow_confirmations;
CREATE POLICY "Admins can view all escrow confirmations"
ON public.escrow_confirmations
FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM profiles
        WHERE profiles.id = auth.uid()
        AND profiles.role = 'admin'
    )
);

-- ============================================================
-- Done. Summary:
-- [1] Sellers CANNOT update orders (policy dropped)
-- [2] Admins CAN update all orders (status, details, etc.)
-- [3] Buyers CAN update their own orders (cancellation)
-- [4] Buyers/Sellers can upsert their own escrow confirmations
-- [5] Admins can view all escrow confirmations
-- ============================================================
