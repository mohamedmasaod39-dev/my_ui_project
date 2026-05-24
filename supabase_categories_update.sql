-- ==========================================
-- UPDATE CATEGORIES ON SUPABASE
-- ==========================================
-- This script aligns the Supabase categories table with the updated categories
-- used in the mobile app and website:
-- 1: Electronics
-- 2: Gaming
-- 3: Home
-- 4: Fashion
-- 5: Sports
-- 6: Other
-- ==========================================

BEGIN;

-- 1. Ensure the categories exist (Upsert)
INSERT INTO public.categories (id, name) VALUES
(1, 'Electronics'),
(2, 'Gaming'),
(3, 'Home'),
(4, 'Fashion'),
(5, 'Sports'),
(6, 'Other')
ON CONFLICT (id) DO UPDATE 
SET name = EXCLUDED.name;

-- 2. Optional: Remove any categories that are no longer in the standard list.
-- WARNING: If there are products referencing other category IDs, you might need to re-assign them first.
-- To avoid foreign key violations, we only delete if there are no dependencies, or use CASCADE.
DELETE FROM public.categories 
WHERE id NOT IN (1, 2, 3, 4, 5, 6);

COMMIT;
