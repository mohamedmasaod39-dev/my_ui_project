-- ============================================================================
-- SQL Fix for Escrow Confirmation "updated_at" Trigger Error
-- Run this script in your Supabase SQL Editor
-- ============================================================================

-- Add the missing updated_at column to public.escrow_confirmations table
ALTER TABLE public.escrow_confirmations 
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- Ensure all other major tables also have updated_at to prevent similar trigger issues
ALTER TABLE public.orders 
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE public.products 
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE public.notifications 
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE public.profiles 
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Recreate the trigger on escrow_confirmations just to make sure it exists
DROP TRIGGER IF EXISTS trg_escrow_confirmations_updated_at ON public.escrow_confirmations;
CREATE TRIGGER trg_escrow_confirmations_updated_at
  BEFORE UPDATE ON public.escrow_confirmations
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============================================================================
-- SQL Fix Applied Successfully!
-- ============================================================================
