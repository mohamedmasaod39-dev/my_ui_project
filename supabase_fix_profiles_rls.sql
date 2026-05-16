-- Allow anyone to read public profiles (needed for viewing seller profiles)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'profiles' 
        AND policyname = 'Public profiles are visible to everyone.'
    ) THEN
        CREATE POLICY "Public profiles are visible to everyone."
        ON public.profiles FOR SELECT
        USING (true);
    END IF;
END
$$;

-- Ensure RLS is enabled so policies actually apply
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
