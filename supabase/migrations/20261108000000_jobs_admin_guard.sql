-- Step A: stop ordinary users from activating / promoting jobs.
--  * is_admin(): true only for auth.jwt() app_metadata.role = 'admin'
--    (app_metadata cannot be edited by the user; user_metadata and profiles are NOT used).
--  * jobs admin UPDATE policy and INSERT policy are tightened.
--  * BEFORE INSERT OR UPDATE trigger resets privileged columns for ordinary users.
--    service_role / postgres (auth.uid() is null) and admins are not touched,
--    so epoint-callback (service_role) keeps activating paid jobs.

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') = 'admin';
$$;

revoke all on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated, service_role;

-- Previously: using (true) with check (true) -> any signed-in user could update any job.
alter policy "Allow admin to update job status" on public.jobs
  using (public.is_admin())
  with check (public.is_admin());

-- Previously: with check (true).
alter policy "Public jobs insert access" on public.jobs
  with check (user_id = auth.uid() or public.is_admin());

-- New jobs must start unapproved.
alter table public.jobs alter column status set default 'pending';

create or replace function public.jobs_guard_privileged_columns()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if auth.uid() is null or public.is_admin() then
    return new;
  end if;

  if tg_op = 'INSERT' then
    -- 'pending_payment' is the client's "waiting for Epoint" marker; it is not an active state.
    new.ad_status := case when new.ad_status = 'pending_payment' then 'pending_payment' else 'pending' end;
    new.status := 'pending';
    new.is_active := false;
    new.is_vip := false;
    new.vip_until := null;
    new.vip_expires_at := null;
    new.is_verified := false;
    new.user_id := auth.uid();
  else
    new.ad_status := old.ad_status;
    new.status := old.status;
    new.is_active := old.is_active;
    new.is_vip := old.is_vip;
    new.vip_until := old.vip_until;
    new.vip_expires_at := old.vip_expires_at;
    new.is_verified := old.is_verified;
  end if;

  return new;
end;
$$;

drop trigger if exists jobs_guard_privileged_columns on public.jobs;
create trigger jobs_guard_privileged_columns
  before insert or update on public.jobs
  for each row execute function public.jobs_guard_privileged_columns();

notify pgrst, 'reload schema';
