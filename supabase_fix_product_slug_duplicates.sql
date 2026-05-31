-- ============================================================
-- FIX: prevent duplicate products.slug insert/update failures
-- Error fixed: duplicate key violates "products_slug_uq"
-- Run this in the Supabase SQL editor.
-- ============================================================

ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS slug TEXT;

CREATE OR REPLACE FUNCTION public.product_slugify(value TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT COALESCE(
    NULLIF(
      TRIM(BOTH '-' FROM REGEXP_REPLACE(
        REGEXP_REPLACE(LOWER(COALESCE(value, 'product')), '[^a-z0-9]+', '-', 'g'),
        '-+',
        '-',
        'g'
      )),
      ''
    ),
    'product'
  );
$$;

-- Fill only missing slugs. Existing non-empty slugs are left unchanged.
WITH fixed AS (
  SELECT
    id,
    public.product_slugify(
      COALESCE(NULLIF(title, ''), NULLIF(name, ''), 'product')
    ) || '-' || id::TEXT AS slug
  FROM public.products
  WHERE slug IS NULL OR BTRIM(slug) = ''
)
UPDATE public.products AS p
SET slug = fixed.slug
FROM fixed
WHERE p.id = fixed.id;

CREATE UNIQUE INDEX IF NOT EXISTS products_slug_uq
  ON public.products (slug)
  WHERE slug IS NOT NULL;

CREATE OR REPLACE FUNCTION public.ensure_unique_product_slug()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  base_slug TEXT;
  candidate_slug TEXT;
  suffix INTEGER := 2;
BEGIN
  base_slug := public.product_slugify(
    COALESCE(NULLIF(NEW.slug, ''), NULLIF(NEW.title, ''), NULLIF(NEW.name, ''), 'product')
  );

  -- Serialize inserts/updates that are competing for the same base slug.
  PERFORM pg_advisory_xact_lock(hashtext('products.slug.' || base_slug));

  candidate_slug := base_slug;
  WHILE EXISTS (
    SELECT 1
    FROM public.products AS p
    WHERE p.slug = candidate_slug
      AND p.id IS DISTINCT FROM NEW.id
  ) LOOP
    candidate_slug := base_slug || '-' || suffix::TEXT;
    suffix := suffix + 1;
  END LOOP;

  NEW.slug := candidate_slug;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_products_unique_slug ON public.products;
CREATE TRIGGER trg_products_unique_slug
  BEFORE INSERT OR UPDATE OF slug, title, name
  ON public.products
  FOR EACH ROW
  EXECUTE FUNCTION public.ensure_unique_product_slug();
