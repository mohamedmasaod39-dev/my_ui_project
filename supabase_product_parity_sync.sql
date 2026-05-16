-- Ensure products table has all website baseline columns for parity
ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS name TEXT,
  ADD COLUMN IF NOT EXISTS image_url TEXT,
  ADD COLUMN IF NOT EXISTS price_minor INTEGER,
  ADD COLUMN IF NOT EXISTS active BOOLEAN DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS category TEXT;

-- Backfill data if columns were just added (optional but recommended)
UPDATE public.products
SET 
  name = COALESCE(name, title),
  image_url = COALESCE(image_url, main_image_url),
  price_minor = COALESCE(price_minor, (price * 100)::integer),
  active = COALESCE(active, (status = 'active'));
