-- Add Seller/Shop Profile fields to the profiles table
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS shop_name TEXT,
ADD COLUMN IF NOT EXISTS bio TEXT,
ADD COLUMN IF NOT EXISTS avatar_url TEXT,
ADD COLUMN IF NOT EXISTS location TEXT,
ADD COLUMN IF NOT EXISTS phone TEXT;

-- Update RLS policies if necessary (usually 'Users can update own profile' covers this)
