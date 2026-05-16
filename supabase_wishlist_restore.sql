-- Restoring Wishlist Table
CREATE TABLE IF NOT EXISTS public.wishlist (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    product_id BIGINT REFERENCES public.products(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(user_id, product_id)
);

-- Enable RLS
ALTER TABLE public.wishlist ENABLE ROW LEVEL SECURITY;

-- Policies
DROP POLICY IF EXISTS "Users can view own wishlist" ON public.wishlist;
CREATE POLICY "Users can view own wishlist" ON public.wishlist
    FOR SELECT TO authenticated USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can add to wishlist" ON public.wishlist;
CREATE POLICY "Users can add to wishlist" ON public.wishlist
    FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can remove from wishlist" ON public.wishlist;
CREATE POLICY "Users can remove from wishlist" ON public.wishlist
    FOR DELETE TO authenticated USING (auth.uid() = user_id);
