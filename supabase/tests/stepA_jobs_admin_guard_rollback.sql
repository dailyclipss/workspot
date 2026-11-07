-- Rollback-only checks for 20261108000000_jobs_admin_guard.sql.
-- Run AFTER the migration in the same transaction. Ends with ROLLBACK.
begin;

create temp table results (n serial, label text, status text, detail text);
grant all on results to public;
grant usage on sequence results_n_seq to public;

create function pg_temp.rec(l text, s text, d text) returns void
language sql security definer as $$
  insert into results (label, status, detail) values (l, s, d);
$$;

create function pg_temp.expect_true(l text, q text) returns void
language plpgsql as $$
declare ok boolean;
begin
  execute q into ok;
  perform pg_temp.rec(l, case when ok is true then 'PASS' else 'FAIL' end,
    case when ok is true then null else 'returned ' || coalesce(ok::text, 'null') end);
exception when others then
  perform pg_temp.rec(l, 'FAIL', sqlstate || ': ' || sqlerrm);
end;
$$;

-- statement must succeed and affect exactly n rows
create function pg_temp.expect_rows(l text, q text, want int) returns void
language plpgsql as $$
declare n int;
begin
  execute q;
  get diagnostics n = row_count;
  perform pg_temp.rec(l, case when n = want then 'PASS' else 'FAIL' end,
    case when n = want then null else 'affected ' || n || ', expected ' || want end);
exception when others then
  perform pg_temp.rec(l, 'FAIL', sqlstate || ': ' || sqlerrm);
end;
$$;

create function pg_temp.expect_fail(l text, q text, code text) returns void
language plpgsql as $$
begin
  begin
    execute q;
  exception when others then
    perform pg_temp.rec(l, case when sqlstate = code then 'PASS' else 'FAIL' end,
      sqlstate || ' ' || sqlerrm);
    return;
  end;
  perform pg_temp.rec(l, 'FAIL', 'statement succeeded, expected ' || code);
end;
$$;

-- users: A, B ordinary; X has user_metadata.role=admin (must NOT count); ADM is admin by app_metadata
insert into auth.users (id, aud, role, email, raw_app_meta_data, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000d1', 'authenticated', 'authenticated', 'a@test.invalid', '{}', '{}'),
  ('00000000-0000-0000-0000-0000000000d2', 'authenticated', 'authenticated', 'b@test.invalid', '{}', '{}'),
  ('00000000-0000-0000-0000-0000000000d3', 'authenticated', 'authenticated', 'x@test.invalid', '{}', '{"role":"admin","is_admin":true}'),
  ('00000000-0000-0000-0000-0000000000d4', 'authenticated', 'authenticated', 'adm@test.invalid', '{"role":"admin"}', '{}');
insert into public.profiles (id, full_name) values ('00000000-0000-0000-0000-0000000000d3', 'X');
-- X also looks like an admin in profiles (must NOT count)
-- (profiles.is_admin cannot be written by app users; set here as the owner role)
update public.profiles set is_admin = true, role = 'admin' where id = '00000000-0000-0000-0000-0000000000d3';

-- fixtures (inserted as postgres: trigger does not touch them)
insert into public.jobs (id, title, user_id, ad_status, status, is_active, is_vip, is_verified) values
  ('00000000-0000-0000-0000-0000000000e1', 'A job', '00000000-0000-0000-0000-0000000000d1', 'pending_payment', 'pending', false, false, false),
  ('00000000-0000-0000-0000-0000000000e2', 'B job', '00000000-0000-0000-0000-0000000000d2', 'pending', 'pending', false, false, false),
  ('00000000-0000-0000-0000-0000000000e3', 'Ownerless', null, 'pending', 'pending', false, false, false);

-- 1) is_admin()
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000d1","role":"authenticated"}', true);
select pg_temp.expect_true('is_admin false for ordinary user', $q$select public.is_admin() = false$q$);
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000d3","role":"authenticated","user_metadata":{"role":"admin","is_admin":true}}', true);
select pg_temp.expect_true('is_admin false for user_metadata/profiles admin', $q$select public.is_admin() = false$q$);
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000d4","role":"authenticated","app_metadata":{"role":"admin"}}', true);
select pg_temp.expect_true('is_admin true for app_metadata.role=admin', $q$select public.is_admin() = true$q$);
select set_config('request.jwt.claims', '', true);
select pg_temp.expect_true('is_admin false without claims', $q$select public.is_admin() = false$q$);
select pg_temp.expect_true('is_admin: security definer, empty search_path, no user_metadata/profiles',
  $q$select prosecdef and proconfig @> array['search_path=""']
            and prosrc not ilike '%user_metadata%' and prosrc not ilike '%profiles%'
       from pg_proc where oid = 'public.is_admin()'::regprocedure$q$);
select pg_temp.expect_true('is_admin not executable by anon',
  $q$select not has_function_privilege('anon', 'public.is_admin()', 'execute')$q$);
select pg_temp.expect_true('guard trigger function is security invoker',
  $q$select not prosecdef from pg_proc where oid = 'public.jobs_guard_privileged_columns()'::regprocedure$q$);
select pg_temp.expect_true('jobs.status default is pending',
  $q$select column_default like '%pending%' from information_schema.columns where table_schema='public' and table_name='jobs' and column_name='status'$q$);

-- 2) ordinary user A on own job: update succeeds, privileged columns unchanged
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000d1","role":"authenticated"}', true);
select pg_temp.expect_rows('A updates own job (privileged + title) -> 1 row, no error',
  $q$update public.jobs set title='A renamed', ad_status='active', status='active', is_active=true, is_vip=true,
            vip_until=now()+interval '30 days', vip_expires_at=now()+interval '30 days', is_verified=true
      where id='00000000-0000-0000-0000-0000000000e1'$q$, 1);
-- 3) A on B's job and ownerless job
select pg_temp.expect_rows('A updates B job -> 0 rows', $q$update public.jobs set ad_status='active', is_vip=true, title='hacked' where id='00000000-0000-0000-0000-0000000000e2'$q$, 0);
select pg_temp.expect_rows('A updates ownerless job -> 0 rows', $q$update public.jobs set ad_status='active', title='hacked' where id='00000000-0000-0000-0000-0000000000e3'$q$, 0);
select pg_temp.expect_rows('A cannot delete own job (no DELETE policy) -> 0 rows', $q$delete from public.jobs where id='00000000-0000-0000-0000-0000000000e1'$q$, 0);
-- insert: active+vip, foreign user_id
select pg_temp.expect_rows('A inserts active+vip job with user_id=B',
  $q$insert into public.jobs (id, title, user_id, ad_status, status, is_active, is_vip, vip_until, vip_expires_at, is_verified)
     values ('00000000-0000-0000-0000-0000000000f1', 'new1', '00000000-0000-0000-0000-0000000000d2', 'active', 'active', true, true, now()+interval '30 days', now()+interval '30 days', true)$q$, 1);
select pg_temp.expect_rows('A inserts job with user_id=null and no status',
  $q$insert into public.jobs (id, title, user_id) values ('00000000-0000-0000-0000-0000000000f2', 'new2', null)$q$, 1);
select pg_temp.expect_rows('A inserts job as pending_payment (app flow)',
  $q$insert into public.jobs (id, title, user_id, ad_status, is_vip) values ('00000000-0000-0000-0000-0000000000f3', 'new3', '00000000-0000-0000-0000-0000000000d1', 'pending_payment', false)$q$, 1);
reset role;

select pg_temp.expect_true('A own job: privileged columns unchanged, title changed',
  $q$select title='A renamed' and ad_status='pending_payment' and status='pending' and is_active=false and is_vip=false
            and vip_until is null and vip_expires_at is null and is_verified=false
       from public.jobs where id='00000000-0000-0000-0000-0000000000e1'$q$);
select pg_temp.expect_true('B job untouched', $q$select title='B job' and ad_status='pending' and is_vip=false from public.jobs where id='00000000-0000-0000-0000-0000000000e2'$q$);
select pg_temp.expect_true('ownerless job untouched', $q$select title='Ownerless' and ad_status='pending' from public.jobs where id='00000000-0000-0000-0000-0000000000e3'$q$);
select pg_temp.expect_true('insert active+vip became pending/false, owner = A',
  $q$select user_id='00000000-0000-0000-0000-0000000000d1' and ad_status='pending' and status='pending' and is_active=false
            and is_vip=false and vip_until is null and vip_expires_at is null and is_verified=false
       from public.jobs where id='00000000-0000-0000-0000-0000000000f1'$q$);
select pg_temp.expect_true('insert with null user_id -> owner = A, pending, inactive',
  $q$select user_id='00000000-0000-0000-0000-0000000000d1' and ad_status='pending' and status='pending' and is_active=false
       from public.jobs where id='00000000-0000-0000-0000-0000000000f2'$q$);
select pg_temp.expect_true('pending_payment insert keeps pending_payment, inactive, non-vip',
  $q$select ad_status='pending_payment' and status='pending' and is_active=false and is_vip=false from public.jobs where id='00000000-0000-0000-0000-0000000000f3'$q$);

-- anon
set local role anon;
select pg_temp.expect_fail('anon cannot insert job', $q$insert into public.jobs (title) values ('x')$q$, '42501');
select pg_temp.expect_rows('anon update -> 0 rows', $q$update public.jobs set ad_status='active' where id='00000000-0000-0000-0000-0000000000e1'$q$, 0);
reset role;

-- X (user_metadata/profiles admin) is just an ordinary user
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000d3","role":"authenticated","user_metadata":{"role":"admin","is_admin":true}}', true);
select pg_temp.expect_rows('X (fake admin) updates B job -> 0 rows', $q$update public.jobs set ad_status='active', is_vip=true where id='00000000-0000-0000-0000-0000000000e2'$q$, 0);
reset role;

-- admin: can do all of it
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000d4","role":"authenticated","app_metadata":{"role":"admin"}}', true);
select pg_temp.expect_rows('admin activates B job + VIP', $q$update public.jobs set ad_status='active', status='active', is_active=true, is_vip=true, vip_until=now()+interval '30 days', is_verified=true where id='00000000-0000-0000-0000-0000000000e2'$q$, 1);
select pg_temp.expect_rows('admin updates ownerless job', $q$update public.jobs set ad_status='active', is_active=true where id='00000000-0000-0000-0000-0000000000e3'$q$, 1);
select pg_temp.expect_rows('admin inserts active job without user_id (admin_add_job)',
  $q$insert into public.jobs (id, title, ad_status, is_active) values ('00000000-0000-0000-0000-0000000000f4', 'admin job', 'active', true)$q$, 1);
reset role;
select pg_temp.expect_true('admin changes persisted untouched by trigger',
  $q$select (select ad_status='active' and status='active' and is_active and is_vip and vip_until is not null and is_verified from public.jobs where id='00000000-0000-0000-0000-0000000000e2')
        and (select ad_status='active' and is_active from public.jobs where id='00000000-0000-0000-0000-0000000000e3')
        and (select ad_status='active' and is_active and user_id is null from public.jobs where id='00000000-0000-0000-0000-0000000000f4')$q$);

-- service_role (epoint-callback style: no sub claim, bypasses RLS) and postgres
set local role service_role;
select set_config('request.jwt.claims', '{"role":"service_role"}', true);
select pg_temp.expect_rows('service_role activates A pending_payment job + VIP (epoint-callback)',
  $q$update public.jobs set ad_status='active', is_active=true, is_vip=true where id='00000000-0000-0000-0000-0000000000e1'$q$, 1);
reset role;
select pg_temp.expect_true('service_role changes persisted',
  $q$select ad_status='active' and is_active and is_vip from public.jobs where id='00000000-0000-0000-0000-0000000000e1'$q$);
select set_config('request.jwt.claims', '', true);
select pg_temp.expect_rows('postgres (no jwt) can update', $q$update public.jobs set is_vip=false where id='00000000-0000-0000-0000-0000000000e1'$q$, 1);
select pg_temp.expect_true('postgres change persisted', $q$select is_vip=false from public.jobs where id='00000000-0000-0000-0000-0000000000e1'$q$);

-- policies
select pg_temp.expect_true('admin update policy uses is_admin()',
  $q$select qual like '%is_admin%' and with_check like '%is_admin%' from pg_policies where tablename='jobs' and policyname='Allow admin to update job status'$q$);
select pg_temp.expect_true('insert policy checks user_id = auth.uid() or is_admin()',
  $q$select with_check like '%user_id%' and with_check like '%is_admin%' from pg_policies where tablename='jobs' and policyname='Public jobs insert access'$q$);

select n, status, label, detail from results order by n;
rollback;
