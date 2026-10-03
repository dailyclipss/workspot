create extension if not exists pgcrypto;

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null,
  body text not null,
  is_read boolean not null default false,
  type text not null,
  created_at timestamptz not null default now()
);

alter table public.notifications enable row level security;

create policy "Users can read their own notifications"
on public.notifications
for select
to authenticated
using (auth.uid() = user_id);

create policy "Users can insert their own notifications"
on public.notifications
for insert
to authenticated
with check (auth.uid() = user_id);

create policy "Users can update their own notifications"
on public.notifications
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);