-- 1. DROP EXISTING REVIEWS INSERT POLICY
DROP POLICY IF EXISTS "Buyers can insert their own reviews" ON public.reviews;

-- 2. RE-CREATE POLICY WITH UPDATED STATUS CHECKS
-- Ensure it accounts for 'delivered' and 'completed' statuses
CREATE POLICY "Buyers can insert their own reviews"
ON public.reviews FOR INSERT
TO authenticated
WITH CHECK (
  auth.uid() = buyer_id
  AND EXISTS (
    SELECT 1 FROM public.orders o
    WHERE o.id = order_id
      AND o.buyer_id = auth.uid()
      AND o.status IN ('delivered', 'completed')
  )
);

-- 3. ENSURE SELECT POLICY EXISTS FOR REVIEWS
DROP POLICY IF EXISTS "Anyone can view reviews" ON public.reviews;
CREATE POLICY "Anyone can view reviews"
ON public.reviews FOR SELECT
TO authenticated, anon
USING (true);

-- 4. ENABLE RLS (just in case)
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
