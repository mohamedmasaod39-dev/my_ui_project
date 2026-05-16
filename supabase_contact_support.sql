create table if not exists public.contact_support_messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  name text not null,
  email text not null,
  phone text not null,
  message text not null,
  status text not null default 'new',
  created_at timestamptz not null default now()
);

alter table public.contact_support_messages enable row level security;

drop policy if exists "Users can create their own support messages"
  on public.contact_support_messages;
create policy "Users can create their own support messages"
  on public.contact_support_messages
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can read their own support messages"
  on public.contact_support_messages;
create policy "Users can read their own support messages"
  on public.contact_support_messages
  for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Admins can read support messages"
  on public.contact_support_messages;
create policy "Admins can read support messages"
  on public.contact_support_messages
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.profiles
      where profiles.id = auth.uid()
        and profiles.role = 'admin'
    )
  );

drop policy if exists "Admins can update support message status"
  on public.contact_support_messages;
create policy "Admins can update support message status"
  on public.contact_support_messages
  for update
  to authenticated
  using (
    exists (
      select 1
      from public.profiles
      where profiles.id = auth.uid()
        and profiles.role = 'admin'
    )
  )
  with check (
    exists (
      select 1
      from public.profiles
      where profiles.id = auth.uid()
        and profiles.role = 'admin'
    )
  );

create index if not exists contact_support_messages_user_id_idx
  on public.contact_support_messages(user_id);

create index if not exists contact_support_messages_created_at_idx
  on public.contact_support_messages(created_at desc);
