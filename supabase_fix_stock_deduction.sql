-- ============================================================
-- FIX: Correct Stock Deduction by Exact Quantity
-- ============================================================
-- This file fixes the stock deduction issue where products
-- were only decremented by 1 instead of the actual quantity purchased.
-- 
-- This trigger deducts stock IMMEDIATELY when order is created (at checkout)
-- to prevent overselling and ensure accurate inventory tracking.
-- ============================================================

-- Remove any conflicting triggers first
DROP TRIGGER IF EXISTS trg_deduct_stock_on_delivery ON public.orders;
DROP TRIGGER IF EXISTS tr_on_order_status_update ON public.orders;
DROP TRIGGER IF EXISTS trg_finalize_order_cancellation ON public.orders;

-- Remove conflicting functions
DROP FUNCTION IF EXISTS public.deduct_stock_on_delivery_confirmation();
DROP FUNCTION IF EXISTS public.deduct_stock_on_delivery();
DROP FUNCTION IF EXISTS public.on_order_status_update();
DROP FUNCTION IF EXISTS public.finalize_order_cancellation();

-- ============================================================
-- FUNCTION: Deduct stock when order items are inserted
-- This is the CORRECT approach - deduct at checkout, not at delivery
-- ============================================================
CREATE OR REPLACE FUNCTION public.deduct_stock_on_order_creation()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    item_record RECORD;
BEGIN
    -- Loop through all order items and deduct stock by exact quantity
    FOR item_record IN 
        SELECT product_id, quantity, product_name, seller_id 
        FROM public.order_items 
        WHERE order_id = NEW.id
    LOOP
        -- Deduct stock by the EXACT quantity ordered
        -- GREATEST(0, ...) ensures stock never goes below 0
        UPDATE public.products 
        SET stock_qty = GREATEST(0, stock_qty - item_record.quantity)
        WHERE id = item_record.product_id;
    END LOOP;
    
    RETURN NEW;
END;
$$;

-- Trigger fires AFTER order items are inserted
DROP TRIGGER IF EXISTS trg_deduct_stock_after_order_items ON public.order_items;
CREATE TRIGGER trg_deduct_stock_after_order_items
AFTER INSERT ON public.order_items
FOR EACH ROW
EXECUTE FUNCTION public.deduct_stock_on_order_creation();

-- ============================================================
-- ALTERNATIVE: If you prefer to deduct at delivery instead
-- (Uncomment the below if checkout deduction causes issues)
-- ============================================================
-- DROP TRIGGER IF EXISTS trg_deduct_stock_after_order_items ON public.order_items;

-- CREATE OR REPLACE FUNCTION public.deduct_stock_on_delivery()
-- RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
-- DECLARE
--     item_record RECORD;
-- BEGIN
--     -- Only deduct stock when order status changes to 'delivered'
--     IF (OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'delivered') THEN
--         FOR item_record IN 
--             SELECT product_id, quantity, product_name, seller_id 
--             FROM public.order_items 
--             WHERE order_id = NEW.id
--         LOOP
--             -- Deduct stock by the EXACT quantity ordered
--             UPDATE public.products 
--             SET stock_qty = GREATEST(0, stock_qty - item_record.quantity)
--             WHERE id = item_record.product_id;
--         END LOOP;
--     END IF;
--     RETURN NEW;
-- END;
-- $$;

-- DROP TRIGGER IF EXISTS trg_deduct_stock_on_delivery ON public.orders;
-- CREATE TRIGGER trg_deduct_stock_on_delivery
-- AFTER UPDATE ON public.orders
-- FOR EACH ROW
-- EXECUTE FUNCTION public.deduct_stock_on_delivery();
