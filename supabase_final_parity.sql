-- 1. MESSAGE SYNC - Use read_at for precision
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS read_at TIMESTAMPTZ;

-- 2. CONTACT TICKETS - Parity with Website Contact Form
CREATE TABLE IF NOT EXISTS public.contact_tickets (
  id         BIGSERIAL PRIMARY KEY,
  user_id    UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  subject    TEXT NOT NULL,
  message    TEXT NOT NULL,
  status     TEXT DEFAULT 'open', -- 'open', 'in-progress', 'resolved'
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. PROFILES - Add 'suspended' status for Admin parity
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_suspended BOOLEAN DEFAULT FALSE;

-- 4. REALTIME - Ensure messages & tickets are reactive
DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
  EXCEPTION WHEN others THEN NULL;
END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.contact_tickets;
  EXCEPTION WHEN others THEN NULL;
END;
END $$;
