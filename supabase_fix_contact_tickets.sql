-- 1. FIX contact_tickets TABLE
-- Ensure subject column exists (it seems to be missing in the database)
ALTER TABLE public.contact_tickets ADD COLUMN IF NOT EXISTS subject TEXT;

-- Ensure message column exists
ALTER TABLE public.contact_tickets ADD COLUMN IF NOT EXISTS message TEXT;

-- Ensure user_id column exists
ALTER TABLE public.contact_tickets ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL;

-- 2. ENABLE RLS
ALTER TABLE public.contact_tickets ENABLE ROW LEVEL SECURITY;

-- 3. POLICIES
DROP POLICY IF EXISTS "Users can insert own tickets" ON public.contact_tickets;
CREATE POLICY "Users can insert own tickets" 
ON public.contact_tickets FOR INSERT 
TO authenticated 
WITH CHECK (auth.uid() = user_id OR user_id IS NULL);

DROP POLICY IF EXISTS "Users can view own tickets" ON public.contact_tickets;
CREATE POLICY "Users can view own tickets" 
ON public.contact_tickets FOR SELECT 
TO authenticated 
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Admins can view all tickets" ON public.contact_tickets;
CREATE POLICY "Admins can view all tickets" 
ON public.contact_tickets FOR SELECT 
TO authenticated 
USING (
  EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE profiles.id = auth.uid() 
      AND profiles.role = 'admin'
  )
);
