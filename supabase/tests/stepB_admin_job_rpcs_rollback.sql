-- Rollback-only checks for 20261108010000_admin_job_rpcs.sql.
-- Run AFTER 20261108000000 and 20261108010000 in the same transaction. Ends with ROLLBACK.
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

create function pg_temp.expect_ok(l text, q text) returns void
language plpgsql as $$
begin
  execute q;
  perform pg_temp.rec(l, 'PASS', null);
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

insert into auth.users (id, aud, role, email, raw_app_meta_data, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000d1', 'authenticated', 'authenticated', 'a@test.invalid', '{}', '{}'),
  ('00000000-0000-0000-0000-0000000000d4', 'authenticated', 'authenticated', 'adm@test.invalid', '{"role":"admin"}', '{}');

insert into public.jobs (id, title, user_id, ad_status, status, is_active, is_vip) values
  ('00000000-0000-0000-0000-0000000000e1', 'A pending', '00000000-0000-0000-0000-0000000000d1', 'pending_payment', 'pending', false, false),
  ('00000000-0000-0000-0000-0000000000e2', 'A rejected', '00000000-0000-0000-0000-0000000000d1', 'rejected', 'rejected', false, false),
  ('00000000-0000-0000-0000-0000000000e3', 'Ownerless', null, 'pending', 'pending', false, false);

select pg_temp.expect_true('rpcs are security invoker with empty search_path',
  $q$select count(*) = 3 and bool_and(not prosecdef) and bool_and(proconfig @> array['search_path=""'])
       from pg_proc where pronamespace = 'public'::regnamespace
        and proname in ('activate_job_admin','set_job_status_admin','set_job_vip_admin')$q$);
select pg_temp.expect_true('rpcs not executable by anon',
  $q$select not has_function_privilege('anon', 'public.activate_job_admin(uuid)', 'execute')
        and not has_function_privilege('anon', 'public.set_job_status_admin(uuid,text)', 'execute')
        and not has_function_privilege('anon', 'public.set_job_vip_admin(uuid,boolean,timestamptz)', 'execute')$q$);

-- ordinary user: clear 42501, nothing changes
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000d1","role":"authenticated"}', true);
set local role authenticated;
select pg_temp.expect_fail('user activate_job_admin -> 42501',
  $q$select public.activate_job_admin('00000000-0000-0000-0000-0000000000e1')$q$, '42501');
select pg_temp.expect_fail('user set_job_status_admin -> 42501',
  $q$select public.set_job_status_admin('00000000-0000-0000-0000-0000000000e1', 'active')$q$, '42501');
select pg_temp.expect_fail('user set_job_vip_admin -> 42501',
  $q$select public.set_job_vip_admin('00000000-0000-0000-0000-0000000000e1', true)$q$, '42501');
reset role;
select pg_temp.expect_true('job e1 untouched after user attempts',
  $q$select ad_status = 'pending_payment' and not is_active and not is_vip
       from public.jobs where id = '00000000-0000-0000-0000-0000000000e1'$q$);

-- anon: no execute privilege
set local role anon;
select pg_temp.expect_fail('anon activate_job_admin -> 42501',
  $q$select public.activate_job_admin('00000000-0000-0000-0000-0000000000e1')$q$, '42501');
reset role;

-- admin
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000d4","role":"authenticated","app_metadata":{"role":"admin"}}', true);
set local role authenticated;
select pg_temp.expect_ok('admin activate_job_admin',
  $q$select public.activate_job_admin('00000000-0000-0000-0000-0000000000e1')$q$);
reset role;
select pg_temp.expect_true('e1 now active/active/is_active',
  $q$select ad_status = 'active' and status = 'active' and is_active
       from public.jobs where id = '00000000-0000-0000-0000-0000000000e1'$q$);

set local role authenticated;
select pg_temp.expect_ok('admin set_job_vip_admin true (ownerless job)',
  $q$select public.set_job_vip_admin('00000000-0000-0000-0000-0000000000e3', true, now() + interval '30 days')$q$);
reset role;
select pg_temp.expect_true('e3 vip, active, vip_until set',
  $q$select is_vip and is_active and ad_status = 'active' and vip_until is not null
       from public.jobs where id = '00000000-0000-0000-0000-0000000000e3'$q$);

set local role authenticated;
select pg_temp.expect_ok('admin set_job_vip_admin false',
  $q$select public.set_job_vip_admin('00000000-0000-0000-0000-0000000000e3', false)$q$);
select pg_temp.expect_fail('vip on rejected job -> 22023',
  $q$select public.set_job_vip_admin('00000000-0000-0000-0000-0000000000e2', true)$q$, '22023');
select pg_temp.expect_ok('admin set_job_status_admin rejected',
  $q$select public.set_job_status_admin('00000000-0000-0000-0000-0000000000e1', 'rejected')$q$);
select pg_temp.expect_fail('invalid status -> 22023',
  $q$select public.set_job_status_admin('00000000-0000-0000-0000-0000000000e1', 'foo')$q$, '22023');
select pg_temp.expect_fail('unknown job -> P0002',
  $q$select public.activate_job_admin('00000000-0000-0000-0000-00000000ffff')$q$, 'P0002');
reset role;
select pg_temp.expect_true('e3 vip cleared; e1 rejected and inactive',
  $q$select (select not is_vip and vip_until is null from public.jobs where id = '00000000-0000-0000-0000-0000000000e3')
        and (select ad_status = 'rejected' and not is_active from public.jobs where id = '00000000-0000-0000-0000-0000000000e1')$q$);

select n, label, status, detail from results order by n;
select count(*) filter (where status = 'PASS') as pass, count(*) filter (where status = 'FAIL') as fail from results;

rollback;
