-- Server-side OTP storage. Only the service_role (Edge Functions) may access it:
-- RLS is enabled and intentionally NO policies exist.
-- Production had a legacy, unused phone_otps (phone, otp_code, created_at, expires_at;
-- 0 rows, plaintext codes). Recreate it with the hashed structure.
drop table if exists public.phone_otps;

create table public.phone_otps (
  id uuid primary key default gen_random_uuid(),
  phone text not null,
  code_hash text not null,
  expires_at timestamptz not null,
  attempts integer not null default 0,
  ip text,
  created_at timestamptz not null default now()
);

create index if not exists phone_otps_phone_created_idx
  on public.phone_otps (phone, created_at desc);
create index if not exists phone_otps_ip_created_idx
  on public.phone_otps (ip, created_at desc);

alter table public.phone_otps enable row level security;

revoke all on public.phone_otps from anon, authenticated;
