-- ============================================================
-- LISTABLES E-COMMERCE APP - FINAL DATABASE MIGRATION
-- Version: 1.0 (May 2026)
-- 
-- This SQL migration sets up the complete database schema with:
-- 1. User profiles with roles (admin, seller, buyer)
-- 2. Products with inventory management
-- 3. Orders and order items
-- 4. Escrow confirmations for secure transactions
-- 5. Reviews system
-- 6. Notifications
-- 7. Complete RLS policies for security
-- 8. Automatic profile creation on signup
--
-- SIGNUP FLOW:
-- - User signs up with full_name and role in metadata
-- - Trigger automatically creates profile with all data
-- - User is signed out and redirected to login
-- - On login, user navigates to correct page based on role
--
-- Run this entire file in Supabase SQL Editor
-- ============================================================

-- ============================================================
-- 1. CREATE ALL TABLES
-- ============================================================

-- Profiles table - User profile information
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT,
  full_name TEXT,
  avatar_url TEXT,
  role TEXT DEFAULT 'buyer' CHECK (role IN ('admin', 'seller', 'buyer')),
  phone TEXT,
  address TEXT,
  city TEXT,
  state TEXT,
  postal_code TEXT,
  country TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Notifications table - User notifications
CREATE TABLE IF NOT EXISTS public.notifications (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT,
  type TEXT DEFAULT 'general',
  read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Orders table - Purchase orders
CREATE TABLE IF NOT EXISTS public.orders (
  id BIGSERIAL PRIMARY KEY,
  buyer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  seller_id UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- Added for escrow visibility
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'confirmed', 'shipped', 'delivered', 'completed', 'cancelled')),
  total_amount DECIMAL(10, 2),
  delivery_confirmed_at TIMESTAMPTZ,
  delivered_by_role TEXT,
  stock_deducted_at TIMESTAMPTZ, -- Essential for one-time deduction
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Order items table - Individual items in orders
CREATE TABLE IF NOT EXISTS public.order_items (
  id BIGSERIAL PRIMARY KEY,
  order_id BIGINT NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  product_id BIGINT NOT NULL,
  seller_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  quantity INT NOT NULL DEFAULT 1,
  price DECIMAL(10, 2),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Products table - Seller products/listings
CREATE TABLE IF NOT EXISTS public.products (
  id BIGSERIAL PRIMARY KEY,
  seller_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  price DECIMAL(10, 2),
  stock_qty INT DEFAULT 0,
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'sold', 'hidden')),
  validated BOOLEAN DEFAULT FALSE,
  active BOOLEAN DEFAULT TRUE, -- Used for sold visibility logic
  visibility TEXT DEFAULT 'visible' CHECK (visibility IN ('visible', 'sold')), -- Used for sold visibility logic
  out_of_stock_since TIMESTAMPTZ, -- Used for sold visibility logic
  image_url TEXT,
  category TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Escrow confirmations table - Secure transaction confirmations
CREATE TABLE IF NOT EXISTS public.escrow_confirmations (
  id BIGSERIAL PRIMARY KEY,
  order_id BIGINT NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('buyer', 'seller')),
  confirmed BOOLEAN NOT NULL DEFAULT FALSE,
  proof_image_url TEXT,
  confirmed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (order_id, role)
);

-- Reviews table - Product and seller reviews
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

-- ============================================================
-- 2. ENABLE ROW LEVEL SECURITY (RLS) ON ALL TABLES
-- ============================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.escrow_confirmations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 3. CREATE RLS POLICIES - PROFILES
-- ============================================================

DROP POLICY IF EXISTS "Users can view their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Public can view seller profiles" ON public.profiles;

CREATE POLICY "Users can view their own profile"
ON public.profiles FOR SELECT
TO authenticated
USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
ON public.profiles FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can insert their own profile"
ON public.profiles FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = id);

CREATE POLICY "Public can view seller profiles"
ON public.profiles FOR SELECT
USING (role = 'seller');

-- ============================================================
-- 4. CREATE RLS POLICIES - NOTIFICATIONS
-- ============================================================

DROP POLICY IF EXISTS "Users can view own notifications" ON public.notifications;

CREATE POLICY "Users can view own notifications"
ON public.notifications FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- ============================================================
-- 5. CREATE RLS POLICIES - ORDERS
-- ============================================================

DROP POLICY IF EXISTS "Buyers can view their orders" ON public.orders;
DROP POLICY IF EXISTS "Sellers can view their orders" ON public.orders;

CREATE POLICY "Buyers can view their orders"
ON public.orders FOR SELECT
TO authenticated
USING (auth.uid() = buyer_id);

CREATE POLICY "Sellers can view their orders"
ON public.orders FOR SELECT
TO authenticated
USING (auth.uid() = seller_id);

-- ============================================================
-- 6. CREATE RLS POLICIES - PRODUCTS
-- ============================================================

DROP POLICY IF EXISTS "Public can view active and sold products" ON public.products;
DROP POLICY IF EXISTS "Sellers can view their products" ON public.products;

CREATE POLICY "Public can view active and sold products"
ON public.products FOR SELECT
USING (validated = TRUE AND (status IN ('active', 'sold') OR visibility IN ('visible', 'sold')));

CREATE POLICY "Sellers can view their products"
ON public.products FOR SELECT
TO authenticated
USING (auth.uid() = seller_id);

-- ============================================================
-- 7. CREATE TRIGGER FUNCTIONS
-- ============================================================

-- Function to update 'updated_at' timestamp on record updates
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$;

-- Function to create profile when user signs up
-- Extracts full_name and role from raw_user_meta_data
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, role, created_at, updated_at)
  VALUES (
    NEW.id,
    NEW.email,
    NEW.raw_user_meta_data->>'full_name',
    CASE 
      WHEN (NEW.raw_user_meta_data->>'role') IN ('admin', 'seller', 'buyer') 
      THEN (NEW.raw_user_meta_data->>'role')
      ELSE 'buyer'
    END,
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO UPDATE
  SET
    email = EXCLUDED.email,
    full_name = COALESCE(EXCLUDED.full_name, public.profiles.full_name),
    role = COALESCE(NULLIF(EXCLUDED.role, ''), public.profiles.role),
    updated_at = NOW();

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'Error in handle_new_user: %', SQLERRM;
  RETURN NEW;
END;
$$;

-- Function to manage product sold status
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

-- Function for one-time stock deduction
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
      stock_qty = GREATEST(0, COALESCE(p.stock_qty, 0) - item_totals.quantity)
    FROM (
      SELECT product_id, SUM(quantity)::INT AS quantity
      FROM public.order_items
      WHERE order_id = NEW.id
      GROUP BY product_id
    ) item_totals
    WHERE p.id = item_totals.product_id;

    NEW.stock_deducted_at := NOW();
    NEW.delivery_confirmed_at := COALESCE(NEW.delivery_confirmed_at, NOW());
    NEW.delivered_by_role := COALESCE(NEW.delivered_by_role, 'system');
  END IF;
  RETURN NEW;
END;
$$;

-- Escrow state machine
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
    SET status = 'delivered'
    WHERE id = NEW.order_id AND status NOT IN ('delivered', 'completed', 'cancelled');
  ELSIF seller_done THEN
    UPDATE public.orders
    SET status = 'shipped'
    WHERE id = NEW.order_id AND status IN ('pending', 'paid', 'confirmed');
  END IF;
  RETURN NEW;
END;
$$;

-- ============================================================
-- 8. CREATE TRIGGERS
-- ============================================================

-- Trigger for automatic profile creation on signup
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Timestamp update triggers
DROP TRIGGER IF EXISTS trg_profiles_updated_at ON public.profiles;
CREATE TRIGGER trg_profiles_updated_at
  BEFORE UPDATE ON public.profiles FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_orders_updated_at ON public.orders;
CREATE TRIGGER trg_orders_updated_at
  BEFORE UPDATE ON public.orders FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_products_updated_at ON public.products;
CREATE TRIGGER trg_products_updated_at
  BEFORE UPDATE ON public.products FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_notifications_updated_at ON public.notifications;
CREATE TRIGGER trg_notifications_updated_at
  BEFORE UPDATE ON public.notifications FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_escrow_confirmations_updated_at ON public.escrow_confirmations;
CREATE TRIGGER trg_escrow_confirmations_updated_at
  BEFORE UPDATE ON public.escrow_confirmations FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

-- Sold visibility trigger
DROP TRIGGER IF EXISTS trg_sync_product_sold_visibility ON public.products;
CREATE TRIGGER trg_sync_product_sold_visibility
  BEFORE INSERT OR UPDATE OF stock_qty, status
  ON public.products
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_product_sold_visibility();

-- Stock deduction trigger
DROP TRIGGER IF EXISTS trg_apply_order_stock_deduction ON public.orders;
CREATE TRIGGER trg_apply_order_stock_deduction
  BEFORE UPDATE OF status
  ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.apply_order_stock_deduction();

-- Escrow sync trigger
DROP TRIGGER IF EXISTS trg_sync_order_from_escrow_confirmations ON public.escrow_confirmations;
CREATE TRIGGER trg_sync_order_from_escrow_confirmations
  AFTER INSERT OR UPDATE OF confirmed
  ON public.escrow_confirmations
  FOR EACH ROW
  WHEN (NEW.confirmed = TRUE)
  EXECUTE FUNCTION public.sync_order_from_escrow_confirmations();

-- ============================================================
-- 9. CREATE INDICES FOR PERFORMANCE
-- ============================================================

CREATE INDEX IF NOT EXISTS profiles_role_idx ON public.profiles(role);
CREATE INDEX IF NOT EXISTS profiles_email_idx ON public.profiles(email);
CREATE INDEX IF NOT EXISTS notifications_user_id_idx ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS orders_buyer_id_idx ON public.orders(buyer_id);
CREATE INDEX IF NOT EXISTS orders_seller_id_idx ON public.orders(seller_id);
CREATE INDEX IF NOT EXISTS orders_status_idx ON public.orders(status);
CREATE INDEX IF NOT EXISTS order_items_order_id_idx ON public.order_items(order_id);
CREATE INDEX IF NOT EXISTS order_items_seller_id_idx ON public.order_items(seller_id);
CREATE INDEX IF NOT EXISTS products_seller_id_idx ON public.products(seller_id);
CREATE INDEX IF NOT EXISTS products_status_idx ON public.products(status);
CREATE INDEX IF NOT EXISTS escrow_confirmations_order_role_idx ON public.escrow_confirmations(order_id, role);
CREATE INDEX IF NOT EXISTS reviews_seller_id_idx ON public.reviews(seller_id);
CREATE INDEX IF NOT EXISTS reviews_buyer_id_idx ON public.reviews(buyer_id);

-- ============================================================
-- 10. ENABLE REALTIME FOR SPECIFIC TABLES
-- ============================================================

ALTER TABLE public.profiles REPLICA IDENTITY FULL;
ALTER TABLE public.orders REPLICA IDENTITY FULL;
ALTER TABLE public.products REPLICA IDENTITY FULL;
ALTER TABLE public.escrow_confirmations REPLICA IDENTITY FULL;
ALTER TABLE public.notifications REPLICA IDENTITY FULL;

-- ============================================================
-- MIGRATION COMPLETE
-- ============================================================
-- 
-- Summary of what was set up:
-- 
-- TABLES:
-- - profiles: User account information with roles
-- - notifications: User notifications
-- - orders: Purchase orders with status tracking
-- - order_items: Individual items in orders
-- - products: Seller product listings
-- - escrow_confirmations: Secure transaction confirmations
-- - reviews: Product/seller reviews
--
-- SECURITY (RLS):
-- - Users can only view/update their own profiles
-- - Public can view seller profiles and active products
-- - Buyers and sellers can only view their own orders
-- - Notifications are private to each user
--
-- AUTOMATION:
-- - New profiles created automatically when user signs up
-- - Full name and role captured from signup metadata
-- - Updated_at timestamps auto-managed on all updates
--
-- FLOW:
-- 1. User signs up with email, password, full_name, role
-- 2. Trigger creates profile with all metadata
-- 3. User is signed out and redirected to login
-- 4. User logs in with credentials
-- 5. Profile exists with correct role/name
-- 6. User navigates to correct page (home/seller_home/admin)
--
-- ============================================================
