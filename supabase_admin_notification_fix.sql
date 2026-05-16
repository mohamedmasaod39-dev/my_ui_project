-- 1. Add metadata support to notifications
ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS data JSONB DEFAULT '{}'::jsonb;

-- 2. Ensure RLS allows admins to see all notifications if needed, 
-- or ensure that the app specifically inserts for admins.
-- For simplicity, we will continue to insert specific notifications for each admin.

-- 3. Optimization: Index on type for faster notification filtering
CREATE INDEX IF NOT EXISTS notifications_type_idx ON public.notifications(type);
