-- ============================================================
-- Feature Updates SQL Script
-- Run this in Supabase SQL Editor (Dashboard → SQL Editor)
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- 1. PRODUCTS TABLE: ensure 'sold' status is allowed
--    (products already have a status column; this ensures the
--     'sold' value is valid and indexable)
-- ─────────────────────────────────────────────────────────────

-- Create index for faster status queries (active + sold)
CREATE INDEX IF NOT EXISTS idx_products_status_validated
    ON products (status, validated);

-- ─────────────────────────────────────────────────────────────
-- 2. NOTIFICATIONS TABLE: ensure 'data' JSONB column exists
--    (needed for product_id, seller_id in product_approval notifications)
-- ─────────────────────────────────────────────────────────────

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'notifications' AND column_name = 'data'
    ) THEN
        ALTER TABLE notifications ADD COLUMN data JSONB DEFAULT '{}';
    END IF;
END $$;

-- ─────────────────────────────────────────────────────────────
-- 3. NOTIFICATIONS TABLE: ensure 'is_dismissed' column exists
-- ─────────────────────────────────────────────────────────────

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'notifications' AND column_name = 'is_dismissed'
    ) THEN
        ALTER TABLE notifications ADD COLUMN is_dismissed BOOLEAN DEFAULT false;
    END IF;
END $$;

-- ─────────────────────────────────────────────────────────────
-- 4. ORDERS TABLE: ensure shipping_price defaults to 0
-- ─────────────────────────────────────────────────────────────

ALTER TABLE orders
    ALTER COLUMN shipping_price SET DEFAULT 0;

-- Optionally reset all existing pending orders to 0 shipping
-- (uncomment if you want to retroactively zero out shipping fees)
-- UPDATE orders SET shipping_price = 0, total_price = subtotal_price
-- WHERE status IN ('pending', 'confirmed');

-- ─────────────────────────────────────────────────────────────
-- 5. TRIGGER: Auto-notify admin when a new product is listed
--    Sends a 'product_approval' notification to all admin users
--    so they can Approve or Revoke directly from notifications.
-- ─────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION notify_admin_new_product()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    admin_id UUID;
BEGIN
    -- Only fire when a product is newly inserted or re-submitted for approval
    IF (TG_OP = 'INSERT') OR
       (TG_OP = 'UPDATE' AND OLD.validated = false AND NEW.validated = false
        AND OLD.status = 'hidden' AND NEW.status = 'pending') THEN

        -- Notify every admin user
        FOR admin_id IN
            SELECT id FROM profiles WHERE role = 'admin'
        LOOP
            INSERT INTO notifications (
                user_id,
                sender_id,
                title,
                body,
                type,
                data
            ) VALUES (
                admin_id,
                NEW.seller_id,
                'New Product Listing',
                'A seller listed a new product: ' || NEW.title || '. Please review and approve or revoke.',
                'product_approval',
                jsonb_build_object(
                    'product_id', NEW.id,
                    'seller_id',  NEW.seller_id
                )
            );
        END LOOP;
    END IF;
    RETURN NEW;
END;
$$;

-- Drop old trigger if it exists, then recreate
DROP TRIGGER IF EXISTS trg_notify_admin_new_product ON products;

CREATE TRIGGER trg_notify_admin_new_product
    AFTER INSERT OR UPDATE ON products
    FOR EACH ROW
    EXECUTE FUNCTION notify_admin_new_product();

-- ─────────────────────────────────────────────────────────────
-- 6. TRIGGER: Deduct stock ONLY when order is delivered
--    (The Flutter app already does this in _updateOrderStatus,
--     but this DB trigger acts as a safety net / server-side enforcement)
-- ─────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION deduct_stock_on_delivery()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    item RECORD;
    current_stock INT;
    new_stock INT;
BEGIN
    -- Only fire when status changes TO 'delivered'
    IF NEW.status = 'delivered' AND OLD.status != 'delivered' THEN
        FOR item IN
            SELECT product_id, quantity FROM order_items
            WHERE order_id = NEW.id
        LOOP
            SELECT stock_qty INTO current_stock
            FROM products WHERE id = item.product_id;

            new_stock := GREATEST(0, current_stock - item.quantity);

            UPDATE products
            SET
                stock_qty = new_stock,
                -- Mark as 'sold' if stock hits 0, otherwise keep 'active'
                status = CASE WHEN new_stock <= 0 THEN 'sold' ELSE status END
            WHERE id = item.product_id;
        END LOOP;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_deduct_stock_on_delivery ON orders;

CREATE TRIGGER trg_deduct_stock_on_delivery
    AFTER UPDATE ON orders
    FOR EACH ROW
    EXECUTE FUNCTION deduct_stock_on_delivery();

-- ─────────────────────────────────────────────────────────────
-- 7. RLS: Admin can update products (for approve / revoke)
-- ─────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "Admins can update any product" ON products;
CREATE POLICY "Admins can update any product" ON products
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM profiles
            WHERE profiles.id = auth.uid()
            AND profiles.role = 'admin'
        )
    );

-- ─────────────────────────────────────────────────────────────
-- 8. RLS: Admin can insert notifications (for approve/revoke feedback)
-- ─────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "Admins can insert notifications" ON notifications;
CREATE POLICY "Admins can insert notifications" ON notifications
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM profiles
            WHERE profiles.id = auth.uid()
            AND profiles.role = 'admin'
        )
    );

-- ─────────────────────────────────────────────────────────────
-- 9. CATEGORIES: Ensure Fashion is a single category (no subcategories)
--    Update name from 'Fashion for Men' to 'Fashion' if needed
-- ─────────────────────────────────────────────────────────────

UPDATE categories
SET name = 'Fashion'
WHERE name ILIKE 'Fashion%' AND name != 'Fashion';

-- ─────────────────────────────────────────────────────────────
-- Done. Summary of changes:
-- [1] Index on products(status, validated) for fast homepage queries
-- [2] notifications.data JSONB column (for product_id, seller_id)
-- [3] notifications.is_dismissed column
-- [4] orders.shipping_price defaults to 0
-- [5] Trigger: notify admins when new product is listed
-- [6] Trigger: deduct stock only when order status → 'delivered'
-- [7] RLS: admins can update products (approve/revoke)
-- [8] RLS: admins can insert notifications
-- [9] Rename 'Fashion for Men' → 'Fashion' in categories
-- ─────────────────────────────────────────────────────────────
