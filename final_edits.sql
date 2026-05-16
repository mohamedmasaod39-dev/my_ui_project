-- 0. Ensure Admin & Baseline Accounts exist in auth.users
-- Password for all baseline accounts will be '123456'
-- Adminstrator
INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, is_super_admin, role)
SELECT 
    gen_random_uuid(), 
    '00000000-0000-0000-0000-000000000000', 
    'admin@admin.com', 
    extensions.crypt('123456', extensions.gen_salt('bf')), 
    now(), 
    '{"provider":"email","providers":["email"]}', 
    '{"full_name":"Administrator"}', 
    false, 
    'authenticated'
WHERE NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'admin@admin.com');

-- Mustafa Hussien
INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, is_super_admin, role)
SELECT 
    gen_random_uuid(), 
    '00000000-0000-0000-0000-000000000000', 
    'mahmoudhussien887@gmail.com', 
    extensions.crypt('123456', extensions.gen_salt('bf')), 
    now(), 
    '{"provider":"email","providers":["email"]}', 
    '{"full_name":"Mustafa Hussien"}', 
    false, 
    'authenticated'
WHERE NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'mahmoudhussien887@gmail.com');

-- 1. Restore Categories: Electronics, Fashion for Men, Women, Kids, Watches, Extras
-- We'll truncate and re-insert to ensure absolute parity with the requested set.
-- Note: This might affect existing products if their category_ids change.
TRUNCATE TABLE categories CASCADE;

INSERT INTO categories (id, name) VALUES
(1, 'Electronics'),
(2, 'Fashion for Men'),
(3, 'Women'),
(4, 'Kids'),
(5, 'Watches'),
(6, 'Extras');

-- 2. Create Contact Tickets table if not exists
CREATE TABLE IF NOT EXISTS contact_tickets (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id),
    name TEXT NOT NULL,
    email TEXT NOT NULL,
    phone TEXT,
    message TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Enable RLS and Permissions for Support
ALTER TABLE contact_tickets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can insert contact tickets" ON contact_tickets;
CREATE POLICY "Anyone can insert contact tickets" ON contact_tickets FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Admins can view contact tickets" ON contact_tickets;
CREATE POLICY "Admins can view contact tickets" ON contact_tickets FOR SELECT USING (
    EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin')
);

-- 4. Create a flattened view for Marketplace Orders to solve "logic tree" parsing errors
-- This allows us to query by seller_id or buyer_id without complex joins in Flutter
CREATE OR REPLACE VIEW admin_marketplace_orders AS
SELECT 
    oi.id as item_id,
    oi.order_id,
    oi.seller_id,
    oi.price,
    oi.quantity,
    oi.product_name,
    o.buyer_id,
    o.status as order_status,
    o.customer_name,
    o.shipping_address,
    o.city,
    o.state,
    o.zipcode,
    o.payment_method,
    o.created_at,
    p.title as product_title,
    p.main_image_url as product_image
FROM order_items oi
JOIN orders o ON oi.order_id = o.id
LEFT JOIN products p ON oi.product_id = p.id;

-- 5. Fix Escrow Confirmations column name (Parity with Flutter code)
DO $$ 
BEGIN 
    -- Ensure proof_image_url exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='escrow_confirmations' AND column_name='proof_image_url') THEN
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='escrow_confirmations' AND column_name='image_url') THEN
            ALTER TABLE escrow_confirmations RENAME COLUMN image_url TO proof_image_url;
        ELSE
            ALTER TABLE escrow_confirmations ADD COLUMN proof_image_url TEXT;
        END IF;
    END IF;
END $$;

-- 6. Grant permissions for the new view
GRANT SELECT ON admin_marketplace_orders TO authenticated;
GRANT SELECT ON admin_marketplace_orders TO service_role;

-- 7. Restore Baseline Sellers and Products
DO $$ 
DECLARE 
    v_ahmed_id UUID;
    v_mustafa_id UUID;
BEGIN
    -- 7.1 Dynamically find existing profiles to assign as our baseline sellers
    -- This avoids FK violations with auth.users
    SELECT id INTO v_ahmed_id FROM profiles ORDER BY id LIMIT 1;
    SELECT id INTO v_mustafa_id FROM profiles WHERE id != v_ahmed_id ORDER BY id LIMIT 1;

    -- 7.2 Update these profiles to match the website's sellers
    IF v_ahmed_id IS NOT NULL THEN
        UPDATE profiles SET 
            full_name = 'Ahmed88', 
            role = 'seller',
            avatar_url = 'https://i.pravatar.cc/150?u=ahmed'
        WHERE id = v_ahmed_id;
    END IF;

    IF v_mustafa_id IS NOT NULL THEN
        UPDATE profiles SET 
            full_name = 'Mustafa Hussien', 
            role = 'seller',
            email = 'mahmoudhussien887@gmail.com',
            phone = '01046995215',
            avatar_url = 'https://i.pravatar.cc/150?u=mustafa'
        WHERE id = v_mustafa_id;
    ELSE
        -- If only one user exists, he takes both roles
        v_mustafa_id := v_ahmed_id;
    END IF;

    -- 7.3 Ensure Administrator profile is set correctly
    -- This matches the website's baseline administrator account
    UPDATE profiles SET 
        full_name = 'Administrator',
        email = 'admin@admin',
        role = 'admin'
    WHERE role = 'admin' OR email = 'admin@admin';

    -- 7.3 Only proceed if we have at least one valid seller profile
    IF v_ahmed_id IS NOT NULL THEN
        -- Clear existing products to ensure absolute baseline parity
        TRUNCATE TABLE products CASCADE;

        -- Ahmed88's Electronics
        INSERT INTO products (seller_id, category_id, title, price, stock_qty, main_image_url, description, status, validated) VALUES
        (v_ahmed_id, 1, 'ASUS FHD Gaming Laptop', 9600, 5, 'https://images.unsplash.com/photo-1593642632823-8f785ba67e45?auto=format&fit=crop&q=80&w=600', 'Powerful gaming laptop with high refresh rate display.', 'active', true),
        (v_ahmed_id, 1, 'GP11 Shooter USB Gamepad', 5500, 15, 'https://images.unsplash.com/photo-1600080972464-8e5f35f63d08?auto=format&fit=crop&q=80&w=600', 'Ergonomic USB gamepad for PC and console gaming.', 'active', true),
        (v_ahmed_id, 1, 'AK-900 Wired Keyboard', 2000, 25, 'https://images.unsplash.com/photo-1595225476474-87563907a212?auto=format&fit=crop&q=80&w=600', 'Tactile wired keyboard with RGB backlighting.', 'active', true);

        -- Mustafa Hussien's Items (or Ahmed if only one user)
        INSERT INTO products (seller_id, category_id, title, price, stock_qty, main_image_url, description, status, validated) VALUES
        (v_mustafa_id, 1, 'HAVIT HV-G92 Gamepad', 1200, 20, 'https://images.unsplash.com/photo-1608256246200-53e635b5b65f?auto=format&fit=crop&q=80&w=600', 'Classic gaming controller with dual vibration.', 'active', true),
        (v_mustafa_id, 1, 'IPS LCD Gaming Monitor', 3700, 12, 'https://images.unsplash.com/photo-1527443154391-507e9dc6c5cc?auto=format&fit=crop&q=80&w=600', 'Crisp IPS display with minimal response time.', 'active', true),
        (v_mustafa_id, 1, 'RGB liquid CPU Cooler', 16000, 10, 'https://images.unsplash.com/photo-1593640408182-31c70c8268f5?auto=format&fit=crop&q=80&w=600', 'High performance liquid cooler with RGB lighting.', 'active', true),
        (v_mustafa_id, 2, 'The north coat', 2600, 10, 'https://images.unsplash.com/photo-1548036328-c9fa89d128fa?auto=format&fit=crop&q=80&w=600', 'Durable and warm winter coat for men.', 'active', true),
        (v_mustafa_id, 2, 'Gucci duffle bag', 5600, 3, 'https://images.unsplash.com/photo-1548036328-c9fa89d128fa?auto=format&fit=crop&q=80&w=600', 'Premium leather duffle bag for travel.', 'active', true),
        (v_mustafa_id, 3, 'Quilted Satin Jacket', 7500, 8, 'https://images.unsplash.com/photo-1591047139829-d91aecb6caea?auto=format&fit=crop&q=80&w=600', 'Luxurious quilted satin jacket for women.', 'active', true),
        (v_mustafa_id, 6, 'S-Series Comfort Chair', 3750, 15, 'https://images.unsplash.com/photo-1595514535402-da78c187b5a8?auto=format&fit=crop&q=80&w=600', 'Ergonomic office chair for maximum comfort.', 'active', true),
        (v_mustafa_id, 6, 'Small BookShelf', 3600, 7, 'https://images.unsplash.com/photo-1594026112284-02bb6f3352fe?auto=format&fit=crop&q=80&w=600', 'Minimalist wooden bookshelf for compact spaces.', 'active', true);
    END IF;
END $$;
