drop policy if exists "Senders can delete own messages" on public.messages;
create policy "Senders can delete own messages"
on public.messages
for delete
to authenticated
using (auth.uid() = sender_id);
