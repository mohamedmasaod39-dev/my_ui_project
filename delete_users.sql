-- ============================================================
-- STRICT DELETE: Remove users and all related data with CASCADE
-- ============================================================
-- This will permanently delete the selected users and cascade delete
-- all their related data in the correct order to respect foreign keys

-- User 1: ahmed hasan (email: ahmed@gmail.com)
-- User 2: amr ahmed (email: amr@gmail.com)

BEGIN;

-- Store the user IDs for deletion
WITH users_to_delete AS (
    SELECT id FROM auth.users
    WHERE email IN ('ahmed@gmail.com', 'amr@gmail.com')
)
-- Delete in order of foreign key dependencies:

-- 1. Delete notifications (references profiles)
DELETE FROM public.notifications
WHERE user_id IN (SELECT id FROM users_to_delete)
   OR sender_id IN (SELECT id FROM users_to_delete);

-- 2. Delete messages (references profiles)
DELETE FROM public.messages
WHERE sender_id IN (SELECT id FROM users_to_delete)
   OR receiver_id IN (SELECT id FROM users_to_delete);

-- 3. Delete order_items (references orders and products)
DELETE FROM public.order_items
WHERE order_id IN (
    SELECT id FROM public.orders
    WHERE buyer_id IN (SELECT id FROM users_to_delete)
       OR seller_id IN (SELECT id FROM users_to_delete)
);

-- 4. Delete orders (references profiles)
DELETE FROM public.orders
WHERE buyer_id IN (SELECT id FROM users_to_delete)
   OR seller_id IN (SELECT id FROM users_to_delete);

-- 5. Delete products (references profiles/sellers)
DELETE FROM public.products
WHERE seller_id IN (SELECT id FROM users_to_delete);

-- 6. Delete cart items
DELETE FROM public.cart_items
WHERE user_id IN (SELECT id FROM users_to_delete);

-- 7. Delete offers (references profiles)
DELETE FROM public.offers
WHERE buyer_id IN (SELECT id FROM users_to_delete)
   OR seller_id IN (SELECT id FROM users_to_delete);

-- 8. Delete reviews
DELETE FROM public.reviews
WHERE reviewer_id IN (SELECT id FROM users_to_delete)
   OR reviewed_user_id IN (SELECT id FROM users_to_delete);

-- 9. Delete wishlists
DELETE FROM public.wishlists
WHERE user_id IN (SELECT id FROM users_to_delete);

-- 10. Delete profiles
DELETE FROM public.profiles
WHERE id IN (SELECT id FROM users_to_delete);

-- 11. Delete from auth.users
DELETE FROM auth.users
WHERE email IN ('ahmed@gmail.com', 'amr@gmail.com');

COMMIT;

-- Verify deletion
SELECT 'Users and all related data deleted successfully!' AS status;
SELECT COUNT(*) as remaining_users FROM auth.users 
WHERE email IN ('ahmed@gmail.com', 'amr@gmail.com');
