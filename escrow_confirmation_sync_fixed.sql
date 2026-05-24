-- ============================================================
-- ESCROW CONFIRMATION SYNC + SOLD PRODUCT VISIBILITY FIX
-- Run this in the Supabase SQL editor after the earlier migrations.
-- ============================================================

-- 1. Required columns used by the mobile and website escrow workflow.
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS seller_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS delivery_confirmed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS delivered_by_role TEXT,
  ADD COLUMN IF NO T EXISTS stock_deducted_at TIMESTAMPTZ;

ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_status_check;

UPDATE public.orders
SET status = 'pending'
WHERE status IS NULL
   OR status NOT IN (
    'pending',
    'paid',
    'confirmed',
    'shipped',
    'delivered',
    'completed',
    'cancelled'
  );

ALTER TABLE public.orders
  ADD CONSTRAINT orders_status_check
  CHECK (
    status IN (
      'pending',
      'paid',
      'confirmed',
      'shipped',
      'delivered',
      'completed',
      'cancelled'
    )
  );

ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS active BOOLEAN DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS visibility TEXT DEFAULT 'visible',
  ADD COLUMN IF NOT EXISTS out_of_stock_since TIMESTAMPTZ;

CREATE TABLE IF NOT EXISTS public.escrow_confirmations (
  id BIGSERIAL PRIMARY KEY,
  order_id BIGINT NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('buyer', 'seller')),
  confirmed BOOLEAN NOT NULL DEFAULT FALSE,
  proof_image_url TEXT,
  confirmed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (order_id, role)
);

CREATE TABLE IF NOT EXISTS public.reviews (
  id BIGSERIAL PRIMARY KEY,
  order_id BIGINT NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  seller_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  buyer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  rating SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (order_id, buyer_id)
);

ALTER TABLE public.escrow_confirmations
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

CREATE OR REPLACE FUNCTION public.set_escrow_confirmation_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_escrow_confirmation_updated_at
  ON public.escrow_confirmations;
CREATE TRIGGER trg_escrow_confirmation_updated_at
  BEFORE UPDATE ON public.escrow_confirmations
  FOR EACH ROW
  EXECUTE FUNCTION public.set_escrow_confirmation_updated_at();

CREATE INDEX IF NOT EXISTS orders_seller_id_idx
  ON public.orders(seller_id);

CREATE INDEX IF NOT EXISTS escrow_confirmations_order_role_idx
  ON public.escrow_confirmations(order_id, role);

CREATE INDEX IF NOT EXISTS products_status_validated_stock_idx
  ON public.products(status, validated, stock_qty);

-- 2. Backfill orders.seller_id so order participants can see escrow rows.
WITH seller_links AS (
  SELECT
    order_id,
    MIN(seller_id::TEXT)::UUID AS seller_id,   -- cast UUID->TEXT for MIN, then back to UUID
    COUNT(DISTINCT seller_id) AS seller_count
  FROM public.order_items
  WHERE seller_id IS NOT NULL
  GROUP BY order_id
)
UPDATE public.orders o
SET seller_id = sl.seller_id
FROM seller_links sl
WHERE o.id = sl.order_id
  AND sl.seller_count = 1
  AND (o.seller_id IS NULL OR o.seller_id <> sl.seller_id);

-- 3. Keep existing escrow rows attached to the real buyer/seller account.
UPDATE public.escrow_confirmations ec
SET user_id = o.buyer_id
FROM public.orders o
WHERE ec.order_id = o.id
  AND ec.role = 'buyer'
  AND o.buyer_id IS NOT NULL
  AND ec.user_id IS DISTINCT FROM o.buyer_id;

WITH seller_links AS (
  SELECT
    o.id AS order_id,
    COALESCE(o.seller_id, MIN(oi.seller_id::TEXT)::UUID) AS seller_id
  FROM public.orders o
  LEFT JOIN public.order_items oi ON oi.order_id = o.id
  GROUP BY o.id, o.seller_id
)
UPDATE public.escrow_confirmations ec
SET user_id = sl.seller_id
FROM seller_links sl
WHERE ec.order_id = sl.order_id
  AND ec.role = 'seller'
  AND sl.seller_id IS NOT NULL
  AND ec.user_id IS DISTINCT FROM sl.seller_id;

-- 4. Helper functions used by policies. SECURITY DEFINER avoids policy recursion.
CREATE OR REPLACE FUNCTION public.is_admin_user(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = p_user_id
      AND p.role = 'admin'
  );
$$;

CREATE OR REPLACE FUNCTION public.is_order_participant(
  p_order_id BIGINT,
  p_user_id UUID
)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT p_user_id IS NOT NULL AND (
    EXISTS (
      SELECT 1
      FROM public.orders o
      WHERE o.id = p_order_id
        AND (o.buyer_id = p_user_id OR o.seller_id = p_user_id)
    )
    OR EXISTS (
      SELECT 1
      FROM public.order_items oi
      WHERE oi.order_id = p_order_id
        AND oi.seller_id = p_user_id
    )
  );
$$;

CREATE OR REPLACE FUNCTION public.can_write_escrow_confirmation(
  p_order_id BIGINT,
  p_user_id UUID,
  p_role TEXT
)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT p_user_id IS NOT NULL AND (
    (
      p_role = 'buyer'
      AND EXISTS (
        SELECT 1
        FROM public.orders o
        WHERE o.id = p_order_id
          AND o.buyer_id = p_user_id
      )
    )
    OR (
      p_role = 'seller'
      AND (
        EXISTS (
          SELECT 1
          FROM public.orders o
          WHERE o.id = p_order_id
            AND o.seller_id = p_user_id
        )
        OR EXISTS (
          SELECT 1
          FROM public.order_items oi
          WHERE oi.order_id = p_order_id
            AND oi.seller_id = p_user_id
        )
      )
    )
  );
$$;

CREATE OR REPLACE FUNCTION public.prevent_locked_escrow_confirmation_update()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF COALESCE(OLD.confirmed, FALSE) = TRUE
     AND COALESCE(auth.role(), '') <> 'service_role'
     AND NOT public.is_admin_user(auth.uid()) THEN
    RAISE EXCEPTION 'Escrow confirmation is locked after submission';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_locked_escrow_confirmation_update
  ON public.escrow_confirmations;
CREATE TRIGGER trg_prevent_locked_escrow_confirmation_update
  BEFORE UPDATE ON public.escrow_confirmations
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_locked_escrow_confirmation_update();

-- 5. Escrow RLS: buyers and sellers can read both rows for their order,
-- but can only write their own role row.
ALTER TABLE public.escrow_confirmations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own confirmations" ON public.escrow_confirmations;
DROP POLICY IF EXISTS "Users can read escrow confirmations for their orders" ON public.escrow_confirmations;
DROP POLICY IF EXISTS "Participants can view escrow confirmations" ON public.escrow_confirmations;
DROP POLICY IF EXISTS "Users can insert own confirmations" ON public.escrow_confirmations;
DROP POLICY IF EXISTS "Users can update own confirmations" ON public.escrow_confirmations;
DROP POLICY IF EXISTS "Users can upsert their own escrow confirmation" ON public.escrow_confirmations;
DROP POLICY IF EXISTS "Admins can view all escrow confirmations" ON public.escrow_confirmations;
DROP POLICY IF EXISTS "Participants can insert own escrow confirmation" ON public.escrow_confirmations;
DROP POLICY IF EXISTS "Participants can update own escrow confirmation" ON public.escrow_confirmations;
DROP POLICY IF EXISTS "Participants can update unconfirmed escrow confirmation" ON public.escrow_confirmations;
DROP POLICY IF EXISTS "Admins can update escrow confirmations" ON public.escrow_confirmations;

CREATE POLICY "Participants can view escrow confirmations"
ON public.escrow_confirmations
FOR SELECT
TO authenticated
USING (
  public.is_order_participant(order_id, auth.uid())
  OR public.is_admin_user(auth.uid())
);

CREATE POLICY "Participants can insert own escrow confirmation"
ON public.escrow_confirmations
FOR INSERT
TO authenticated
WITH CHECK (
  auth.uid() = user_id
  AND public.can_write_escrow_confirmation(order_id, auth.uid(), role)
  AND confirmed = TRUE
  AND NULLIF(BTRIM(COALESCE(proof_image_url, '')), '') IS NOT NULL
);

CREATE POLICY "Participants can update unconfirmed escrow confirmation"
ON public.escrow_confirmations
FOR UPDATE
TO authenticated
USING (
  auth.uid() = user_id
  AND public.can_write_escrow_confirmation(order_id, auth.uid(), role)
  AND COALESCE(confirmed, FALSE) = FALSE
)
WITH CHECK (
  auth.uid() = user_id
  AND public.can_write_escrow_confirmation(order_id, auth.uid(), role)
  AND confirmed = TRUE
  AND NULLIF(BTRIM(COALESCE(proof_image_url, '')), '') IS NOT NULL
);

CREATE POLICY "Admins can update escrow confirmations"
ON public.escrow_confirmations
FOR UPDATE
TO authenticated
USING (public.is_admin_user(auth.uid()))
WITH CHECK (public.is_admin_user(auth.uid()));

-- 6. Realtime support for both confirmation and order status changes.
ALTER TABLE public.escrow_confirmations REPLICA IDENTITY FULL;
ALTER TABLE public.orders REPLICA IDENTITY FULL;
ALTER TABLE public.products REPLICA IDENTITY FULL;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.escrow_confirmations;
EXCEPTION
  WHEN duplicate_object THEN NULL;
  WHEN undefined_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
EXCEPTION
  WHEN duplicate_object THEN NULL;
  WHEN undefined_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.products;
EXCEPTION
  WHEN duplicate_object THEN NULL;
  WHEN undefined_object THEN NULL;
END $$;

-- 7. Keep product records visible when stock reaches zero.
CREATE OR REPLACE FUNCTION public.sync_product_sold_visibility()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF COALESCE(NEW.stock_qty, 0) <= 0 THEN
    IF COALESCE(NEW.status, '') <> 'hidden' THEN
      NEW.status := 'sold';
    END IF;
    NEW.active := FALSE;
    NEW.visibility := 'sold';
    NEW.out_of_stock_since := COALESCE(NEW.out_of_stock_since, NOW());
  ELSIF NEW.status = 'active' THEN
    NEW.active := TRUE;
    IF NEW.visibility = 'sold' THEN
      NEW.visibility := 'visible';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_product_sold_visibility ON public.products;
CREATE TRIGGER trg_sync_product_sold_visibility
  BEFORE INSERT OR UPDATE OF stock_qty, status
  ON public.products
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_product_sold_visibility();

UPDATE public.products
SET
  status = CASE WHEN COALESCE(status, '') = 'hidden' THEN status ELSE 'sold' END,
  active = FALSE,
  visibility = 'sold',
  out_of_stock_since = COALESCE(out_of_stock_since, NOW())
WHERE COALESCE(stock_qty, 0) <= 0;

-- 8. One-time stock deduction per order. This replaces older stock triggers
-- that could deduct more than once.
DROP TRIGGER IF EXISTS trg_deduct_stock_on_delivery ON public.orders;
DROP TRIGGER IF EXISTS trg_deduct_stock_on_delivery_confirmation ON public.orders;

CREATE OR REPLACE FUNCTION public.apply_order_stock_deduction()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF OLD.stock_deducted_at IS NULL
     AND NEW.stock_deducted_at IS NULL
     AND NEW.status IN ('delivered', 'completed') THEN
    UPDATE public.products p
    SET
      stock_qty = GREATEST(0, COALESCE(p.stock_qty, 0) - item_totals.quantity),
      status = CASE
        WHEN GREATEST(0, COALESCE(p.stock_qty, 0) - item_totals.quantity) <= 0
             AND COALESCE(p.status, '') <> 'hidden'
          THEN 'sold'
        ELSE p.status
      END,
      active = CASE
        WHEN GREATEST(0, COALESCE(p.stock_qty, 0) - item_totals.quantity) <= 0
          THEN FALSE
        ELSE p.active
      END,
      visibility = CASE
        WHEN GREATEST(0, COALESCE(p.stock_qty, 0) - item_totals.quantity) <= 0
          THEN 'sold'
        ELSE p.visibility
      END,
      out_of_stock_since = CASE
        WHEN GREATEST(0, COALESCE(p.stock_qty, 0) - item_totals.quantity) <= 0
          THEN COALESCE(p.out_of_stock_since, NOW())
        ELSE p.out_of_stock_since
      END
    FROM (
      SELECT product_id, SUM(quantity)::INT AS quantity
      FROM public.order_items
      WHERE order_id = NEW.id
      GROUP BY product_id
    ) item_totals
    WHERE p.id = item_totals.product_id;

    NEW.stock_deducted_at := NOW();
    NEW.delivery_confirmed_at := COALESCE(NEW.delivery_confirmed_at, NOW());
    NEW.delivered_by_role := COALESCE(NEW.delivered_by_role, 'escrow');
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_apply_order_stock_deduction ON public.orders;
CREATE TRIGGER trg_apply_order_stock_deduction
  BEFORE UPDATE OF status, delivery_confirmed_at
  ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.apply_order_stock_deduction();

-- If an older notification trigger exists, keep its notifications but remove
-- stock mutation from that function so stock is only deducted by the trigger above.
CREATE OR REPLACE FUNCTION public.on_order_status_update()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  seller_id UUID;
BEGIN
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    BEGIN
      INSERT INTO public.notifications (user_id, title, body, type)
      VALUES (
        NEW.buyer_id,
        'Order ' || INITCAP(NEW.status),
        'Your order #' || NEW.id || ' status is now ' || UPPER(NEW.status) || '.',
        'order'
      );
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;

    FOR seller_id IN
      SELECT DISTINCT oi.seller_id
      FROM public.order_items oi
      WHERE oi.order_id = NEW.id
        AND oi.seller_id IS NOT NULL
    LOOP
      BEGIN
        INSERT INTO public.notifications (user_id, title, body, type)
        VALUES (
          seller_id,
          'Order ' || INITCAP(NEW.status),
          'Order #' || NEW.id || ' status is now ' || UPPER(NEW.status) || '.',
          'order'
        );
      EXCEPTION WHEN OTHERS THEN
        NULL;
      END;
    END LOOP;
  END IF;

  RETURN NEW;
END;
$$;

-- 9. Escrow confirmation state machine:
-- seller confirmed -> shipped, both confirmed -> delivered and ready for admin release.
CREATE OR REPLACE FUNCTION public.sync_order_from_escrow_confirmations()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  buyer_done BOOLEAN := FALSE;
  seller_done BOOLEAN := FALSE;
BEGIN
  SELECT
    COALESCE(BOOL_OR(role = 'buyer' AND confirmed), FALSE),
    COALESCE(BOOL_OR(role = 'seller' AND confirmed), FALSE)
  INTO buyer_done, seller_done
  FROM public.escrow_confirmations
  WHERE order_id = NEW.order_id;

  IF buyer_done AND seller_done THEN
    UPDATE public.orders
    SET
      status = 'delivered',
      delivery_confirmed_at = COALESCE(delivery_confirmed_at, NOW()),
      delivered_by_role = COALESCE(delivered_by_role, 'escrow')
    WHERE id = NEW.order_id
      AND status NOT IN ('delivered', 'completed', 'cancelled');
  ELSIF seller_done THEN
    UPDATE public.orders
    SET status = 'shipped'
    WHERE id = NEW.order_id
      AND status IN ('pending', 'paid', 'confirmed');
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_order_from_escrow_confirmations
  ON public.escrow_confirmations;
CREATE TRIGGER trg_sync_order_from_escrow_confirmations
  AFTER INSERT OR UPDATE OF confirmed
  ON public.escrow_confirmations
  FOR EACH ROW
  WHEN (NEW.confirmed = TRUE)
  EXECUTE FUNCTION public.sync_order_from_escrow_confirmations();

-- 10. Public listing policy: validated active and sold products remain readable.
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public can view active and sold products" ON public.products;
CREATE POLICY "Public can view active and sold products"
ON public.products
FOR SELECT
USING (
  validated = TRUE
  AND (
    status IN ('active', 'sold')
    OR visibility IN ('visible', 'sold')
  )
);

-- 11. Reviews unlock only after the escrow workflow is fully released.
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Reviews are publicly readable" ON public.reviews;
DROP POLICY IF EXISTS "Anyone can view reviews" ON public.reviews;
DROP POLICY IF EXISTS "Buyers can insert their own reviews" ON public.reviews;
DROP POLICY IF EXISTS "Buyers can insert reviews for completed orders" ON public.reviews;

CREATE POLICY "Reviews are publicly readable"
ON public.reviews
FOR SELECT
TO authenticated, anon
USING (TRUE);

CREATE POLICY "Buyers can insert reviews for completed orders"
ON public.reviews
FOR INSERT
TO authenticated
WITH CHECK (
  auth.uid() = buyer_id
  AND EXISTS (
    SELECT 1
    FROM public.orders o
    WHERE o.id = order_id
      AND o.buyer_id = auth.uid()
      AND o.status = 'completed'
  )
);

-- ============================================================
-- Done.
-- Buyers and sellers can now read both escrow rows in realtime.
-- Each role can submit its escrow confirmation once; after confirmed it is locked.
-- Seller confirmation moves the order to shipped.
-- Both confirmations move the order to delivered and deduct stock once.
-- Reviews can only be inserted after the order is completed.
-- Zero-stock products remain visible as sold/out-of-stock listings.
-- ============================================================
