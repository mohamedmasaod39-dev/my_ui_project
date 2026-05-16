-- Database Triggers for Automatic Notifications & Inventory (Final Corrected Version)
-- Optimized for safety, reliability, and full coverage of Admin, Seller, and Buyer.

-- 1. Helper function to find the site admin
CREATE OR REPLACE FUNCTION public.get_admin_id()
RETURNS UUID AS $$
    SELECT id FROM public.profiles WHERE role = 'admin' LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER;

-- 2. Message Notification (Notify Receiver)
CREATE OR REPLACE FUNCTION public.on_message_insert()
RETURNS TRIGGER AS $$
BEGIN
    BEGIN
        INSERT INTO public.notifications (user_id, sender_id, title, body, type)
        VALUES (NEW.receiver_id, NEW.sender_id, 'New Message', LEFT(NEW.body, 50), 'message');
    EXCEPTION WHEN OTHERS THEN
        NULL; -- Failsafe: ensures message insertion never fails
    END;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_on_message_insert ON public.messages;
CREATE TRIGGER tr_on_message_insert
AFTER INSERT ON public.messages
FOR EACH ROW
EXECUTE FUNCTION public.on_message_insert();

-- 3. Order Placement Notification (Notify Seller & Admin)
CREATE OR REPLACE FUNCTION public.on_order_insert()
RETURNS TRIGGER AS $$
DECLARE
    admin_id UUID;
BEGIN
    BEGIN
        admin_id := public.get_admin_id();

        -- Notify Seller
        IF NEW.seller_id IS NOT NULL THEN
            INSERT INTO public.notifications (user_id, sender_id, title, body, type)
            VALUES (NEW.seller_id, NEW.buyer_id, 'New Order Received', 'You have a new order from ' || COALESCE(NEW.customer_name, 'a buyer'), 'order');
        END IF;

        -- Notify Admin
        IF admin_id IS NOT NULL THEN
            INSERT INTO public.notifications (user_id, sender_id, title, body, type)
            VALUES (admin_id, NEW.buyer_id, 'New Site Order', 'Order #' || NEW.id || ' placed by ' || COALESCE(NEW.customer_name, 'a buyer'), 'order');
        END IF;
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_on_order_insert ON public.orders;
CREATE TRIGGER tr_on_order_insert
AFTER INSERT ON public.orders
FOR EACH ROW
EXECUTE FUNCTION public.on_order_insert();

-- 4. Order Status Update (Notify Buyer & Seller + Stock Update)
CREATE OR REPLACE FUNCTION public.on_order_status_update()
RETURNS TRIGGER AS $$
DECLARE
    item_record RECORD;
BEGIN
    BEGIN
        -- Notify Buyer about any status change (Confirmed, Shipped, Delivered, etc.)
        IF (OLD.status IS DISTINCT FROM NEW.status) THEN
            INSERT INTO public.notifications (user_id, title, body, type)
            VALUES (
                NEW.buyer_id, 
                'Order ' || INITCAP(NEW.status), 
                'Your order #' || NEW.id || ' status is now ' || UPPER(NEW.status) || '.', 
                'order'
            );
        END IF;

        -- Stock Decrement ONLY when status changes to 'delivered'
        IF (OLD.status IS DISTINCT FROM 'delivered' AND NEW.status = 'delivered') THEN
            FOR item_record IN 
                SELECT product_id, quantity, product_name, seller_id 
                FROM public.order_items 
                WHERE order_id = NEW.id
            LOOP
                -- Decrement stock safely
                UPDATE public.products 
                SET stock_qty = GREATEST(0, stock_qty - item_record.quantity)
                WHERE id = item_record.product_id;

                -- Notify Seller about delivery and stock adjustment
                INSERT INTO public.notifications (user_id, title, body, type)
                VALUES (
                    item_record.seller_id, 
                    'Product Delivered & Stock Updated', 
                    'Your product "' || item_record.product_name || '" was delivered. Stock has been adjusted.', 
                    'order'
                );
            END LOOP;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_on_order_status_update ON public.orders;
CREATE TRIGGER tr_on_order_status_update
AFTER UPDATE ON public.orders
FOR EACH ROW
EXECUTE FUNCTION public.on_order_status_update();

-- 5. Offer Notification (Notify Seller on New, Notify Buyer on Update)
CREATE OR REPLACE FUNCTION public.on_offer_action()
RETURNS TRIGGER AS $$
DECLARE
    product_title TEXT;
BEGIN
    BEGIN
        SELECT title INTO product_title FROM public.products WHERE id = NEW.product_id;

        -- Case A: New Offer Created -> Notify Seller
        IF (TG_OP = 'INSERT') THEN
            INSERT INTO public.notifications (user_id, sender_id, title, body, type)
            VALUES (NEW.seller_id, NEW.buyer_id, 'New Offer Received', 'New offer on "' || COALESCE(product_title, 'your product') || '"', 'offer');
        
        -- Case B: Offer Status Updated -> Notify Buyer
        ELSIF (TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status AND NEW.status IN ('accepted', 'rejected')) THEN
            INSERT INTO public.notifications (user_id, title, body, type)
            VALUES (
                NEW.buyer_id, 
                'Offer ' || INITCAP(NEW.status), 
                'Your offer on "' || COALESCE(product_title, 'product') || '" was ' || NEW.status || '.', 
                'offer'
            );
        END IF;
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_on_offer_action ON public.offers;
CREATE TRIGGER tr_on_offer_action
AFTER INSERT OR UPDATE ON public.offers
FOR EACH ROW
EXECUTE FUNCTION public.on_offer_action();

-- 6. New Product Notification (Notify Admin)
CREATE OR REPLACE FUNCTION public.on_product_insert()
RETURNS TRIGGER AS $$
DECLARE
    admin_id UUID;
BEGIN
    BEGIN
        admin_id := public.get_admin_id();

        IF admin_id IS NOT NULL THEN
            INSERT INTO public.notifications (user_id, sender_id, title, body, type)
            VALUES (admin_id, NEW.seller_id, 'New Product Listed', 'Product "' || NEW.title || '" has been added to the shop.', 'product');
        END IF;
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_on_product_insert ON public.products;
CREATE TRIGGER tr_on_product_insert
AFTER INSERT ON public.products
FOR EACH ROW
EXECUTE FUNCTION public.on_product_insert();

-- 7. New User Notification (Notify Admin)
CREATE OR REPLACE FUNCTION public.on_profile_insert()
RETURNS TRIGGER AS $$
DECLARE
    admin_id UUID;
BEGIN
    BEGIN
        admin_id := public.get_admin_id();

        -- Only notify if it's a buyer or seller joining
        IF admin_id IS NOT NULL AND NEW.role != 'admin' THEN
            INSERT INTO public.notifications (user_id, title, body, type)
            VALUES (admin_id, 'New User Joined', 'A new ' || NEW.role || ' (' || COALESCE(NEW.full_name, NEW.email) || ') has registered.', 'user');
        END IF;
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_on_profile_insert ON public.profiles;
CREATE TRIGGER tr_on_profile_insert
AFTER INSERT ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.on_profile_insert();
