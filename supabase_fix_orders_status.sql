-- 1. DROP EXISTING CONSTRAINT (if named 'orders_status_check')
ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_status_check;

-- 2. ADD UPDATED CONSTRAINT
-- Includes: pending, confirmed, shipped, delivered, completed, cancelled
ALTER TABLE public.orders ADD CONSTRAINT orders_status_check 
  CHECK (status IN ('pending', 'confirmed', 'shipped', 'delivered', 'completed', 'cancelled'));

-- 3. ENSURE ALL CURRENT ORDERS HAVE VALID STATUS
-- (Safety backfill if any rows were somehow set to something else)
UPDATE public.orders SET status = 'pending' WHERE status NOT IN ('pending', 'confirmed', 'shipped', 'delivered', 'completed', 'cancelled');
