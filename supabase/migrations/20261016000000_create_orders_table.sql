create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  order_id text not null unique,
  user_id uuid references auth.users (id) on delete set null,
  status text not null default 'pending',
  payment_info jsonb,
  created_at timestamptz not null default now()
);

alter table public.orders enable row level security;

create policy "Users can read their own orders"
on public.orders
for select
to authenticated
using (auth.uid() = user_id);
