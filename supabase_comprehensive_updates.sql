-- ============================================================
-- COMPREHENSIVE UPDATES: All Feature Implementations
-- Run this in Supabase SQL Editor
-- ============================================================

-- ============================================================
-- 1. SHIPPING COST MANAGEMENT
-- Ensure shipping_price defaults to 0 and is only calculated at checkout
-- ============================================================
ALTER TABLE public.orders
ADD COLUMN IF NOT EXISTS shipping_cost_type TEXT DEFAULT 'free' CHECK (shipping_cost_type IN ('free', 'calculated')),
ADD COLUMN IF NOT EXISTS shipping_calculated_at TIMESTAMPTZ;

-- Update existing orders to have free shipping
UPDATE public.orders
SET shipping_price = 0, shipping_cost_type = 'free'
WHERE shipping_price IS NULL OR shipping_price = 0;

CREATE INDEX IF NOT EXISTS orders_shipping_cost_type_idx ON public.orders(shipping_cost_type);

-- ============================================================
-- 2. PRODUCT STOCK MANAGEMENT
-- Track stock deduction timing and visibility of out-of-stock items
-- ============================================================
ALTER TABLE public.products
ADD COLUMN IF NOT EXISTS visibility TEXT DEFAULT 'visible' CHECK (visibility IN ('visible', 'hidden', 'sold')),
ADD COLUMN IF NOT EXISTS stock_deducted_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS out_of_stock_since TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS products_visibility_idx ON public.products(visibility);
CREATE INDEX IF NOT EXISTS products_stock_deducted_at_idx ON public.products(stock_deducted_at);

-- ============================================================
-- 3. ORDER CANCELLATION & ACTION TRACKING
-- Track cancellations and prevent further actions
-- ============================================================
ALTER TABLE public.orders
ADD COLUMN IF NOT EXISTS cancellation_finalized BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS cancellation_finalized_at TIMESTAMPTZ;

-- When cancelled, no further actions can be performed
CREATE INDEX IF NOT EXISTS orders_cancellation_finalized_idx ON public.orders(cancellation_finalized);

-- ============================================================
-- 4. PRODUCT LISTING APPROVAL & ADMIN NOTIFICATIONS
-- Add product_listing_approved and notification system
-- ============================================================
ALTER TABLE public.products
ADD COLUMN IF NOT EXISTS admin_approved BOOLEAN DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS admin_approved_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS approval_notification_sent BOOLEAN DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS products_admin_approved_idx ON public.products(admin_approved);

-- Ensure notifications table has required columns
ALTER TABLE public.notifications
ADD COLUMN IF NOT EXISTS product_id BIGINT REFERENCES public.products(id) ON DELETE CASCADE,
ADD COLUMN IF NOT EXISTS action_type TEXT DEFAULT 'view'; -- 'view', 'approve', 'revoke'

CREATE INDEX IF NOT EXISTS notifications_product_id_idx ON public.notifications(product_id);

-- ============================================================
-- 5. ORDER STATUS ENHANCEMENTS
-- Add delivery_confirmed_at to track when stock should be deducted
-- ============================================================
ALTER TABLE public.orders
ADD COLUMN IF NOT EXISTS delivery_confirmed_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS delivered_by_role TEXT; -- 'seller' or 'system'

CREATE INDEX IF NOT EXISTS orders_delivery_confirmed_at_idx ON public.orders(delivery_confirmed_at);

-- ============================================================
-- 6. SELLER DASHBOARD PRODUCT CLICKABILITY
-- Ensure products have seller_id and are trackable
-- ============================================================
-- Already exists, but ensure seller_id is indexed
CREATE INDEX IF NOT EXISTS products_seller_id_idx ON public.products(seller_id);

-- ============================================================
-- 7. SUBCATEGORIES REMOVAL
-- Remove subcategory from listing_details (handled in app code)
-- This is primarily an app-level change, SQL just ensures clean data
-- ============================================================
-- Clean up any existing subcategories in listing_details
-- This is done via app code, but we can verify data:
-- SELECT id, listing_details->>'subcategory' FROM public.products WHERE listing_details->>'subcategory' IS NOT NULL;

-- ============================================================
-- 8. TRIGGER: Automatically set out_of_stock_since when stock reaches 0
-- ============================================================
CREATE OR REPLACE FUNCTION public.set_out_of_stock_timestamp()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  -- When stock reaches 0 and visibility is 'visible', mark as 'sold'
  IF NEW.stock_qty <= 0 AND OLD.stock_qty > 0 THEN
    NEW.visibility = 'sold';
    NEW.out_of_stock_since = NOW();
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_set_out_of_stock_timestamp ON public.products;
CREATE TRIGGER trg_set_out_of_stock_timestamp
  BEFORE UPDATE ON public.products
  FOR EACH ROW
  EXECUTE FUNCTION public.set_out_of_stock_timestamp();

-- ============================================================
-- 9. TRIGGER: Prevent actions on cancelled orders
-- ============================================================
CREATE OR REPLACE FUNCTION public.prevent_actions_on_cancelled_order()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.orders
    WHERE id = NEW.order_id AND cancellation_finalized = TRUE
  ) THEN
    RAISE EXCEPTION 'Cannot perform actions on a cancelled order';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_actions_on_cancelled_order ON public.order_items;
CREATE TRIGGER trg_prevent_actions_on_cancelled_order
  BEFORE INSERT OR UPDATE ON public.order_items
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_actions_on_cancelled_order();

-- ============================================================
-- 10. TRIGGER: When order is cancelled, mark cancellation as finalized
-- ============================================================
CREATE OR REPLACE FUNCTION public.finalize_order_cancellation()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  -- When cancelled_by_role is set, finalize cancellation
  IF NEW.cancelled_by_role IS NOT NULL AND OLD.cancelled_by_role IS NULL THEN
    NEW.cancellation_finalized = TRUE;
    NEW.cancellation_finalized_at = NOW();
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_finalize_order_cancellation ON public.orders;
CREATE TRIGGER trg_finalize_order_cancellation
  BEFORE UPDATE ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.finalize_order_cancellation();

-- ============================================================
-- 11. TRIGGER: Deduct stock only when order is confirmed as delivered
-- ============================================================
CREATE OR REPLACE FUNCTION public.deduct_stock_on_delivery_confirmation()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  -- When delivery is confirmed and stock hasn't been deducted yet
  IF NEW.delivery_confirmed_at IS NOT NULL 
     AND OLD.delivery_confirmed_at IS NULL THEN
    -- Deduct stock for each order item
    UPDATE public.products
    SET stock_qty = GREATEST(0, stock_qty - oi.quantity)
    FROM public.order_items oi
    WHERE oi.order_id = NEW.id AND products.id = oi.product_id
      AND products.stock_deducted_at IS NULL;
    
    -- Mark products as stock deducted
    UPDATE public.products
    SET stock_deducted_at = NOW()
    WHERE id IN (
      SELECT product_id FROM public.order_items WHERE order_id = NEW.id
    ) AND stock_deducted_at IS NULL;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_deduct_stock_on_delivery ON public.orders;
CREATE TRIGGER trg_deduct_stock_on_delivery
  AFTER UPDATE ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.deduct_stock_on_delivery_confirmation();

-- ============================================================
-- 12. RLS POLICY: Sellers can only see their own products in dashboard
-- ============================================================
DROP POLICY IF EXISTS "Sellers can view their own products in dashboard" ON public.products;
CREATE POLICY "Sellers can view their own products in dashboard"
  ON public.products FOR SELECT
  USING (auth.uid()::text = seller_id OR 
         (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin');

-- ============================================================
-- 13. FUNCTION: Mark product as sold (visibility)
-- ============================================================
CREATE OR REPLACE FUNCTION public.mark_product_as_sold(product_id BIGINT)
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  UPDATE public.products
  SET visibility = 'sold', out_of_stock_since = NOW()
  WHERE id = product_id AND stock_qty <= 0;
$$;

-- ============================================================
-- 14. FUNCTION: Restore cancelled order's reserved stock
-- ============================================================
CREATE OR REPLACE FUNCTION public.restore_stock_on_order_cancellation()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  -- When order is cancelled, restore stock
  IF NEW.cancelled_by_role IS NOT NULL AND OLD.cancelled_by_role IS NULL THEN
    UPDATE public.products
    SET stock_qty = stock_qty + oi.quantity
    FROM public.order_items oi
    WHERE oi.order_id = NEW.id AND products.id = oi.product_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_restore_stock_on_cancellation ON public.orders;
CREATE TRIGGER trg_restore_stock_on_cancellation
  BEFORE UPDATE ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.restore_stock_on_order_cancellation();

-- ============================================================
-- 15. BACKFILL: Set visibility for products with 0 stock
-- ============================================================
UPDATE public.products
SET visibility = 'sold', out_of_stock_since = NOW()
WHERE stock_qty <= 0 AND visibility != 'sold';

-- ============================================================
-- SUMMARY OF CHANGES:
-- ✓ Shipping cost: Set to 0 by default, only calculated at checkout
-- ✓ Out-of-stock products: Show with 'sold' label, don't disappear
-- ✓ Stock deduction: Only when order confirmed as delivered
-- ✓ Order cancellation: Actions disappear, no further actions possible
-- ✓ Admin notifications: System ready to notify admins of new listings
-- ✓ Product approval: Admin can approve/revoke listings
-- ✓ Seller dashboard: Ready for clickable products (app-level change)
-- ✓ Subcategories: Ready to be removed (app-level change)
-- ============================================================
