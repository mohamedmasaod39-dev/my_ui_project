-- 1. Remove 'condition' column from products table
ALTER TABLE public.products DROP COLUMN IF EXISTS condition;

-- 2. Clean up listing_details JSONB to keep only allowed keys: 'Color', 'Size', 'subcategory'
UPDATE public.products
SET listing_details = (
  SELECT jsonb_object_agg(key, value)
  FROM jsonb_each(listing_details)
  WHERE key IN ('Color', 'Size', 'subcategory')
)
WHERE listing_details IS NOT NULL AND listing_details != '{}'::jsonb;

-- 3. Ensure any null listing_details are initialized to empty object
UPDATE public.products
SET listing_details = '{}'::jsonb
WHERE listing_details IS NULL;
