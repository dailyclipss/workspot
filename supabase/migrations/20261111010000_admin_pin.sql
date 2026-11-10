-- Server-side admin PIN. The PIN never ships in a client bundle: only its bcrypt hash lives here,
-- and it is checked by verify_admin_pin(), which additionally requires the signed admin claim.
-- No PIN value is stored in this migration; set it with the local-only set_admin_pin.sql snippet.

create extension if not exists pgcrypto with schema extensions;

create table if not exists public.admin_pin (
  id smallint primary key default 1 check (id = 1),
  pin_hash text,
  failed_attempts integer not null default 0,
  locked_until timestamptz
);

alter table public.admin_pin enable row level security;
alter table public.admin_pin force row level security;
revoke all on public.admin_pin from public, anon, authenticated;

insert into public.admin_pin (id) values (1) on conflict (id) do nothing;

-- Returns true on a correct PIN, false on a wrong PIN or when no PIN is set.
-- Raises 42501 for non-admin callers and 'admin_pin_locked' (P0423) while locked out.
create or replace function public.verify_admin_pin(p_pin text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_hash text;
  v_failed integer;
  v_locked timestamptz;
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'admin role required' using errcode = '42501';
  end if;

  select pin_hash, failed_attempts, locked_until
    into v_hash, v_failed, v_locked
    from public.admin_pin
   where id = 1
     for update;

  if v_locked is not null and v_locked > now() then
    raise exception 'admin_pin_locked' using errcode = 'P0423';
  end if;

  if v_hash is null or p_pin is null or length(p_pin) < 1 or length(p_pin) > 128 then
    return false;
  end if;

  if v_hash = extensions.crypt(p_pin, v_hash) then
    update public.admin_pin set failed_attempts = 0, locked_until = null where id = 1;
    return true;
  end if;

  v_failed := v_failed + 1;
  if v_failed >= 5 then
    update public.admin_pin
       set failed_attempts = 0, locked_until = now() + interval '15 minutes'
     where id = 1;
  else
    update public.admin_pin set failed_attempts = v_failed where id = 1;
  end if;
  return false;
end;
$$;

revoke all on function public.verify_admin_pin(text) from public, anon;
grant execute on function public.verify_admin_pin(text) to authenticated;
