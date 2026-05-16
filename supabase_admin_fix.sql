-- 1. Create a function to check if a user is an admin without causing recursion
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN (
    SELECT (role = 'admin')
    FROM public.profiles
    WHERE id = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Drop the old problematic policies
DROP POLICY IF EXISTS "Admins can view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;

-- 3. Create new clean policies
-- Allow users to view their own profile
CREATE POLICY "Users can view own profile"
ON public.profiles
FOR SELECT
TO authenticated
USING ( auth.uid() = id );

-- Allow admins to view all profiles (using the non-recursive function)
CREATE POLICY "Admins can view all profiles"
ON public.profiles
FOR SELECT
TO authenticated
USING ( is_admin() );

-- Optional: Performance indexes for badge counts
CREATE INDEX IF NOT EXISTS idx_notifications_unread ON public.notifications(user_id) WHERE (is_read = false);
CREATE INDEX IF NOT EXISTS idx_messages_unread ON public.messages(receiver_id) WHERE (read_at IS NULL);
