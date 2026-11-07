-- Step B: admin job actions as RPCs (requires 20261108000000_jobs_admin_guard.sql).
-- SECURITY INVOKER on purpose: the caller's RLS still applies, so the admin UPDATE
-- policy and the privileged-column trigger (which lets admins through) stay the real gate.
-- The explicit is_admin() check only turns a silent "0 rows" into a clear 42501 error.

create or replace function public.activate_job_admin(p_job_id uuid)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'admin role required' using errcode = '42501';
  end if;

  update public.jobs
     set ad_status = 'active', status = 'active', is_active = true
   where id = p_job_id;

  if not found then
    raise exception 'job not found or not updatable' using errcode = 'P0002';
  end if;
end;
$$;

create or replace function public.set_job_status_admin(p_job_id uuid, p_status text)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'admin role required' using errcode = '42501';
  end if;

  if p_status is null or p_status not in
     ('active', 'approved', 'pending', 'pending_payment', 'rejected', 'deleted') then
    raise exception 'invalid status' using errcode = '22023';
  end if;

  update public.jobs
     set ad_status = p_status,
         status = p_status,
         is_active = (p_status in ('active', 'approved'))
   where id = p_job_id;

  if not found then
    raise exception 'job not found or not updatable' using errcode = 'P0002';
  end if;
end;
$$;

-- VIP on: job becomes visible (active). VIP off: only the VIP flag/dates are cleared.
-- Rejected/deleted jobs cannot be promoted.
create or replace function public.set_job_vip_admin(
  p_job_id uuid,
  p_vip boolean,
  p_until timestamptz default null
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_status text;
begin
  if not public.is_admin() then
    raise exception 'admin role required' using errcode = '42501';
  end if;

  select ad_status into v_status from public.jobs where id = p_job_id;
  if not found then
    raise exception 'job not found or not updatable' using errcode = 'P0002';
  end if;

  if p_vip then
    if v_status in ('rejected', 'deleted') then
      raise exception 'rejected or deleted job cannot be VIP' using errcode = '22023';
    end if;
    update public.jobs
       set is_vip = true,
           vip_until = p_until,
           vip_expires_at = p_until,
           ad_status = 'active',
           status = 'active',
           is_active = true
     where id = p_job_id;
  else
    update public.jobs
       set is_vip = false,
           vip_until = null,
           vip_expires_at = null,
           ad_status = case when ad_status = 'vip' then 'active' else ad_status end,
           status = case when status = 'vip' then 'active' else status end
     where id = p_job_id;
  end if;

  if not found then
    raise exception 'job not found or not updatable' using errcode = 'P0002';
  end if;
end;
$$;

revoke all on function public.activate_job_admin(uuid) from public, anon;
revoke all on function public.set_job_status_admin(uuid, text) from public, anon;
revoke all on function public.set_job_vip_admin(uuid, boolean, timestamptz) from public, anon;
grant execute on function public.activate_job_admin(uuid) to authenticated, service_role;
grant execute on function public.set_job_status_admin(uuid, text) to authenticated, service_role;
grant execute on function public.set_job_vip_admin(uuid, boolean, timestamptz) to authenticated, service_role;
