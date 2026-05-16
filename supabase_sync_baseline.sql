-- ============================================================
-- SYNC BASELINE: Website Parity (Users & Products)
-- Run this in Supabase SQL Editor
-- ============================================================

-- 1. CLEANUP: Delete all users EXCEPT Mustafa Hussien
-- This solves the "Database error loading user" error in the dashboard.
DELETE FROM auth.users 
WHERE email NOT IN ('mahmoudhussien887@gmail.com');

-- (The script below will then re-create the official Admin, Buyer, and Ahmed88 accounts correctly)

-- 2. SEED AUTH USERS (Password: '123456' for all)
-- Administrator
INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, is_super_admin, role)
SELECT 
    gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 
    'admin@admin', extensions.crypt('123456', extensions.gen_salt('bf')), 
    now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Administrator"}', false, 'authenticated'
WHERE NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'admin@admin');

-- Mustafa Hussien (Seller)
INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, is_super_admin, role)
SELECT 
    gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 
    'mahmoudhussien887@gmail.com', extensions.crypt('123456', extensions.gen_salt('bf')), 
    now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Mustafa Hussien"}', false, 'authenticated'
WHERE NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'mahmoudhussien887@gmail.com');

-- Ahmed88 (Seller)
INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, is_super_admin, role)
SELECT 
    gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 
    'ahmed88@gmail.com', extensions.crypt('123456', extensions.gen_salt('bf')), 
    now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Ahmed88"}', false, 'authenticated'
WHERE NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'ahmed88@gmail.com');

-- Buyer Account (Standard Buyer)
INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, is_super_admin, role)
SELECT 
    gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 
    'buyer@buyer.com', extensions.crypt('123456', extensions.gen_salt('bf')), 
    now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Regular Buyer"}', false, 'authenticated'
WHERE NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'buyer@buyer.com');

-- 3. SYNC PROFILES
-- Profiles are auto-created by triggers usually, but we ensure roles match.
UPDATE public.profiles SET role = 'admin', full_name = 'Administrator' WHERE email = 'admin@admin';
UPDATE public.profiles SET role = 'seller', full_name = 'Mustafa Hussien' WHERE email = 'mahmoudhussien887@gmail.com';
UPDATE public.profiles SET role = 'seller', full_name = 'Ahmed88' WHERE email = 'ahmed88@gmail.com';
UPDATE public.profiles SET role = 'buyer', full_name = 'Regular Buyer' WHERE email = 'buyer@buyer.com';

-- 4. SEED PRODUCTS (Parity with Website)
DO $$ 
DECLARE 
    v_mustafa_id UUID;
    v_ahmed_id UUID;
BEGIN
    SELECT id INTO v_mustafa_id FROM profiles WHERE email = 'mahmoudhussien887@gmail.com';
    SELECT id INTO v_ahmed_id FROM profiles WHERE email = 'ahmed88@gmail.com';

    IF v_mustafa_id IS NOT NULL AND v_ahmed_id IS NOT NULL THEN
        -- Clear existing products to ensure absolute parity
        TRUNCATE TABLE products CASCADE;

        -- Mustafa's Listings
        INSERT INTO products (seller_id, category_id, title, price, stock_qty, main_image_url, description, status, validated) VALUES
        (v_mustafa_id, 1, 'HAVIT HV-G92 Gamepad', 1200, 20, 'https://images.unsplash.com/photo-1628191010210-a59de33e5941?auto=format&fit=crop&q=80&w=600', 'Classic gaming controller with dual vibration.', 'active', true),
        (v_mustafa_id, 1, 'AK-900 Wired Keyboard', 9600, 15, 'https://images.unsplash.com/photo-1595225476474-87563907a212?auto=format&fit=crop&q=80&w=600', 'Tactile wired keyboard with RGB backlighting.', 'active', true),
        (v_mustafa_id, 1, 'IPS LCD Gaming Monitor', 3700, 10, 'https://images.unsplash.com/photo-1527443154391-507e9dc6c5cc?auto=format&fit=crop&q=80&w=600', 'Crisp IPS display with minimal response time.', 'active', true),
        (v_mustafa_id, 1, 'RGB liquid CPU Cooler', 16000, 5, 'https://images.unsplash.com/photo-1593640408182-31c70c8268f5?auto=format&fit=crop&q=80&w=600', 'High performance liquid cooler with RGB lighting.', 'active', true);

        -- Ahmed88's Listings
        INSERT INTO products (seller_id, category_id, title, price, stock_qty, main_image_url, description, status, validated) VALUES
        (v_ahmed_id, 1, 'ASUS FHD Gaming Laptop', 9600, 5, 'https://images.unsplash.com/photo-1593642632823-8f785ba67e45?auto=format&fit=crop&q=80&w=600', 'Powerful gaming laptop with high refresh rate display.', 'active', true),
        (v_ahmed_id, 2, 'The north coat', 2600, 10, 'https://images.unsplash.com/photo-1591047139829-d91aecb6caea?auto=format&fit=crop&q=80&w=600', 'Durable and warm winter coat for men.', 'active', true),
        (v_ahmed_id, 2, 'Gucci duffle bag', 5600, 3, 'https://images.unsplash.com/photo-1548036328-c9fa89d128fa?auto=format&fit=crop&q=80&w=600', 'Premium leather duffle bag for travel.', 'active', true),
        (v_ahmed_id, 6, 'Small BookShelf', 3600, 7, 'https://images.unsplash.com/photo-1594026112284-02bb6f3352fe?auto=format&fit=crop&q=80&w=600', 'Minimalist wooden bookshelf for compact spaces.', 'active', true);
    END IF;
END $$;
