-- ============================================================================
-- SQL Fixes for Supabase Row-Level Security (RLS) & Profile Creation
-- Run this script in your Supabase SQL Editor
-- ============================================================================

-- 1. Ensure Row-Level Security (RLS) is enabled on the profiles table
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 2. Drop existing policies to recreate them cleanly and avoid conflicts
DROP POLICY IF EXISTS "Users can view their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Public can view seller profiles" ON public.profiles;
DROP POLICY IF EXISTS "Public profiles are visible to everyone." ON public.profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON public.profiles;

-- 3. Create SELECT policy for authenticated users (to view their own profile)
CREATE POLICY "Users can view their own profile"
ON public.profiles
FOR SELECT
TO authenticated
USING (auth.uid() = id);

-- 4. Create UPDATE policy for authenticated users (to modify their own profile)
CREATE POLICY "Users can update their own profile"
ON public.profiles
FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- 5. Create INSERT policy for authenticated users (required for client-side fallback upserts)
CREATE POLICY "Users can insert their own profile"
ON public.profiles
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = id);

-- 6. Create SELECT policy for everyone to read public profiles (needed for viewing seller profiles)
CREATE POLICY "Public profiles are visible to everyone."
ON public.profiles
FOR SELECT
USING (true);

-- 7. Fix the handle_new_user trigger function to correctly extract 
--    full_name and role from user metadata on signup
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
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    CASE 
      WHEN (NEW.raw_user_meta_data->>'role') IN ('admin', 'seller', 'buyer') 
      THEN (NEW.raw_user_meta_data->>'role')
      ELSE 'buyer'
    END,
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO UPDATE 
  SET email = EXCLUDED.email, 
      full_name = CASE 
                    WHEN EXCLUDED.full_name <> '' THEN EXCLUDED.full_name 
                    ELSE public.profiles.full_name 
                  END,
      role = COALESCE(NULLIF(EXCLUDED.role, ''), public.profiles.role),
      updated_at = NOW();

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Log error details if trigger encounters issues (visible in database logs)
  RAISE LOG 'Error in handle_new_user trigger: %', SQLERRM;
  RETURN NEW;
END;
$$;

-- 8. Re-associate the trigger on auth.users table
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================================
-- SQL fixes applied successfully!
-- ============================================================================
