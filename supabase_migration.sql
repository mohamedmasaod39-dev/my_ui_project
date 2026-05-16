-- ============================================================
-- MIGRATION: Orders, Escrow Confirmations, Reviews
-- Run this in Supabase SQL Editor
-- ============================================================

-- ============================================================
-- 1. ORDERS TABLE - Add missing columns
-- ============================================================
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS subtotal_price      NUMERIC(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS shipping_price      NUMERIC(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS currency            TEXT NOT NULL DEFAULT 'EGP',
  ADD COLUMN IF NOT EXISTS cancelled_by_role   TEXT,          -- 'buyer' | 'seller' | 'admin'
  ADD COLUMN IF NOT EXISTS admin_cancel_reason TEXT,
  ADD COLUMN IF NOT EXISTS card_holder_name    TEXT,
  ADD COLUMN IF NOT EXISTS card_last4          TEXT,
  ADD COLUMN IF NOT EXISTS card_expiry         TEXT,
  ADD COLUMN IF NOT EXISTS customer_name       TEXT,
  ADD COLUMN IF NOT EXISTS customer_email      TEXT,
  ADD COLUMN IF NOT EXISTS phone_number        TEXT,
  ADD COLUMN IF NOT EXISTS company             TEXT,
  ADD COLUMN IF NOT EXISTS shipping_address    TEXT,
  ADD COLUMN IF NOT EXISTS address_line2       TEXT,
  ADD COLUMN IF NOT EXISTS city                TEXT,
  ADD COLUMN IF NOT EXISTS state               TEXT,
  ADD COLUMN IF NOT EXISTS zipcode             TEXT,
  ADD COLUMN IF NOT EXISTS payment_method      TEXT;

-- ============================================================
-- 2. ORDER_ITEMS TABLE - Add seller_id + product_name snapshot
-- ============================================================
ALTER TABLE public.order_items
  ADD COLUMN IF NOT EXISTS seller_id    UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS product_name TEXT;

-- ============================================================
-- 3. ESCROW_CONFIRMATIONS TABLE
-- Stores per-role confirmation for each order (buyer + seller)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.escrow_confirmations (
  id              BIGSERIAL PRIMARY KEY,
  order_id        BIGINT NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  user_id         UUID   NOT NULL REFERENCES auth.users(id)   ON DELETE CASCADE,
  role            TEXT   NOT NULL CHECK (role IN ('buyer', 'seller')),
  confirmed       BOOLEAN NOT NULL DEFAULT FALSE,
  proof_image_url TEXT,
  confirmed_at    TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (order_id, role)
);

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_escrow_confirmations_updated_at ON public.escrow_confirmations;
CREATE TRIGGER trg_escrow_confirmations_updated_at
  BEFORE UPDATE ON public.escrow_confirmations
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- RLS for escrow_confirmations
ALTER TABLE public.escrow_confirmations ENABLE ROW LEVEL SECURITY;

-- Buyer/Seller can read confirmations for their own orders
CREATE POLICY "Users can read escrow confirmations for their orders"
  ON public.escrow_confirmations FOR SELECT
  USING (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1 FROM public.orders o
      WHERE o.id = order_id
        AND (o.buyer_id = auth.uid() OR o.seller_id = auth.uid())
    )
  );

-- Users can insert/update only their own role confirmation
CREATE POLICY "Users can upsert their own escrow confirmation"
  ON public.escrow_confirmations FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- 4. REVIEWS TABLE
-- One review per buyer per order
-- ============================================================
CREATE TABLE IF NOT EXISTS public.reviews (
  id         BIGSERIAL PRIMARY KEY,
  order_id   BIGINT NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  seller_id  UUID   NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  buyer_id   UUID   NOT NULL REFERENCES auth.users(id)    ON DELETE CASCADE,
  rating     SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment    TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (order_id, buyer_id)  -- one review per order per buyer
);

ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

-- Anyone can read reviews
CREATE POLICY "Reviews are publicly readable"
  ON public.reviews FOR SELECT
  USING (TRUE);

-- Only the buyer can insert a review for their own order
CREATE POLICY "Buyers can insert their own reviews"
  ON public.reviews FOR INSERT
  WITH CHECK (
    auth.uid() = buyer_id
    AND EXISTS (
      SELECT 1 FROM public.orders o
      WHERE o.id = order_id
        AND o.buyer_id = auth.uid()
        AND o.status IN ('delivered', 'completed')
    )
  );

-- ============================================================
-- 5. NOTIFICATIONS TABLE - Add sender_id if missing
-- ============================================================
ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS sender_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS type      TEXT DEFAULT 'general';

-- ============================================================
-- 6. PROFILES TABLE - Seller shop fields (from existing SQL)
-- ============================================================
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS shop_name  TEXT,
  ADD COLUMN IF NOT EXISTS bio        TEXT,
  ADD COLUMN IF NOT EXISTS avatar_url TEXT,
  ADD COLUMN IF NOT EXISTS location   TEXT,
  ADD COLUMN IF NOT EXISTS phone      TEXT;

-- ============================================================
-- 7. ENABLE REALTIME for orders and order_items
-- ============================================================
ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
ALTER PUBLICATION supabase_realtime ADD TABLE public.order_items;
ALTER PUBLICATION supabase_realtime ADD TABLE public.escrow_confirmations;
