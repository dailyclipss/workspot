alter table public.orders
  add column if not exists amount numeric(10, 2),
  add column if not exists package_id text,
  add column if not exists target_id text,
  add column if not exists target_type text;
