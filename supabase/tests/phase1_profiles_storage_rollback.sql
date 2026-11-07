-- Rollback-only checks for 20261107010000_harden_profiles_storage.sql.
-- Run AFTER the migration inside the same transaction (or on a staging DB where it
-- is already applied). Nothing is persisted: the script ends with ROLLBACK.
-- Every check records PASS/FAIL into a temp table; the last SELECT lists them all.
begin;

create temp table results (n serial, label text, status text, detail text);
grant all on results to public;
grant usage on sequence results_n_seq to public;

create function pg_temp.rec(l text, s text, d text) returns void
language sql security definer as $$
  insert into results (label, status, detail) values (l, s, d);
$$;

-- statement must fail with the given SQLSTATE
create function pg_temp.expect_fail(l text, q text, code text) returns void
language plpgsql as $$
begin
  begin
    execute q;
  exception when others then
    if sqlstate = code then
      perform pg_temp.rec(l, 'PASS', sqlstate || ' ' || sqlerrm);
    else
      perform pg_temp.rec(l, 'FAIL', 'expected ' || code || ' got ' || sqlstate || ': ' || sqlerrm);
    end if;
    return;
  end;
  perform pg_temp.rec(l, 'FAIL', 'expected ' || code || ' but statement succeeded');
end;
$$;

-- statement must succeed
create function pg_temp.expect_ok(l text, q text) returns void
language plpgsql as $$
begin
  execute q;
  perform pg_temp.rec(l, 'PASS', null);
exception when others then
  perform pg_temp.rec(l, 'FAIL', sqlstate || ': ' || sqlerrm);
end;
$$;

-- query must return true
create function pg_temp.expect_true(l text, q text) returns void
language plpgsql as $$
declare ok boolean;
begin
  execute q into ok;
  perform pg_temp.rec(l, case when ok is true then 'PASS' else 'FAIL' end, case when ok is true then null else 'returned ' || coalesce(ok::text, 'null') end);
exception when others then
  perform pg_temp.rec(l, 'FAIL', sqlstate || ': ' || sqlerrm);
end;
$$;

-- Test users: A and B have profiles, C has none.
insert into auth.users (id, aud, role, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'authenticated', 'authenticated', 'a@test.invalid'),
  ('00000000-0000-0000-0000-0000000000a2', 'authenticated', 'authenticated', 'b@test.invalid'),
  ('00000000-0000-0000-0000-0000000000a3', 'authenticated', 'authenticated', 'c@test.invalid');
insert into public.profiles (id, full_name, phone) values
  ('00000000-0000-0000-0000-0000000000a1', 'User A', '+994500000001'),
  ('00000000-0000-0000-0000-0000000000a2', 'User B', '+994500000002');

-- 1) anon cannot read/write profiles
set local role anon;
select pg_temp.expect_fail('anon cannot read profiles.phone', 'select phone from public.profiles', '42501');
select pg_temp.expect_fail('anon cannot insert profiles', $q$insert into public.profiles (id) values (gen_random_uuid())$q$, '42501');
reset role;

-- 2) authenticated B reads own profile (all app columns incl. role/is_admin), not A's
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a2","role":"authenticated"}', true);
select pg_temp.expect_true('B reads own row: id, full_name, phone, profession, cv_path, cv_name, role, is_admin, updated_at',
  $q$select count(*) = 1 and bool_and(id is not null and full_name = 'User B' and phone = '+994500000002'
        and role = 'user' and is_admin = false and updated_at is not null
        and profession is null and cv_path is null and cv_name is null)
     from public.profiles where id = auth.uid()$q$);
select pg_temp.expect_true('B sees exactly one profile row',
  $q$select count(*) = 1 from public.profiles$q$);
select pg_temp.expect_true('B does not see A profile',
  $q$select count(*) = 0 from public.profiles where id = '00000000-0000-0000-0000-0000000000a1'$q$);

-- 3) non-admin cannot write is_admin / role
select pg_temp.expect_fail('B cannot set is_admin', $q$update public.profiles set is_admin = true where id = auth.uid()$q$, '42501');
select pg_temp.expect_fail('B cannot set role', $q$update public.profiles set role = 'admin' where id = auth.uid()$q$, '42501');

-- 4) own update works; someone else's affects 0 rows
select pg_temp.expect_ok('B updates own profile',
  $q$update public.profiles
        set full_name = 'B renamed', profession = 'dev', phone = '+994500000099',
            cv_path = 'x/y.pdf', cv_name = 'y.pdf', updated_at = now()
      where id = auth.uid()$q$);
select pg_temp.expect_true('B own update persisted',
  $q$select full_name = 'B renamed' and cv_name = 'y.pdf' from public.profiles where id = auth.uid()$q$);
create function pg_temp.update_other() returns int language plpgsql as $$
declare n int;
begin
  update public.profiles set full_name = 'hacked' where id = '00000000-0000-0000-0000-0000000000a1';
  get diagnostics n = row_count;
  return n;
end;
$$;
select pg_temp.expect_true('B cannot update A profile (0 rows)', $q$select pg_temp.update_other() = 0$q$);

-- 5) cannot delete a profile row
select pg_temp.expect_fail('B cannot delete profile', $q$delete from public.profiles where id = auth.uid()$q$, '42501');
reset role;

-- 6) user without a profile can insert only allowed columns
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a3","role":"authenticated"}', true);
select pg_temp.expect_fail('C cannot insert is_admin=true', $q$insert into public.profiles (id, is_admin) values (auth.uid(), true)$q$, '42501');
select pg_temp.expect_fail('C cannot insert role=admin', $q$insert into public.profiles (id, role) values (auth.uid(), 'admin')$q$, '42501');
select pg_temp.expect_fail('C cannot insert profile for another id',
  $q$insert into public.profiles (id, full_name) values ('00000000-0000-0000-0000-0000000000a1', 'x')$q$, '42501');
select pg_temp.expect_ok('C inserts own profile (app columns)',
  $q$insert into public.profiles (id, full_name, phone, profession, updated_at)
     values (auth.uid(), 'User C', '+994500000003', 'tester', now())$q$);
reset role;
select pg_temp.expect_true('C profile stays non-admin',
  $q$select is_admin = false and role = 'user' from public.profiles where id = '00000000-0000-0000-0000-0000000000a3'$q$);

-- 7) storage: avatars
set local role anon;
select pg_temp.expect_fail('anon cannot upload avatar', $q$insert into storage.objects (bucket_id, name) values ('avatars', 'anon/x.jpg')$q$, '42501');
reset role;

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a2","role":"authenticated"}', true);
select pg_temp.expect_ok('B uploads avatar to own folder',
  $q$insert into storage.objects (bucket_id, name)
     values ('avatars', '00000000-0000-0000-0000-0000000000a2/1700000000000.jpg')$q$);
select pg_temp.expect_fail('B cannot upload avatar to A folder',
  $q$insert into storage.objects (bucket_id, name)
     values ('avatars', '00000000-0000-0000-0000-0000000000a1/evil.jpg')$q$, '42501');
select pg_temp.expect_fail('B cannot upload avatar to root',
  $q$insert into storage.objects (bucket_id, name) values ('avatars', 'evil.jpg')$q$, '42501');
reset role;

set local role anon;
select pg_temp.expect_true('anon still reads avatars (public)',
  $q$select count(*) = 1 from storage.objects
     where bucket_id = 'avatars' and name like '00000000-0000-0000-0000-0000000000a2/%'$q$);
reset role;

-- 8) buckets
select pg_temp.expect_true('resumes is private, 10MB, pdf only',
  $q$select public = false and file_size_limit = 10485760 and allowed_mime_types = array['application/pdf']
     from storage.buckets where id = 'resumes'$q$);
select pg_temp.expect_true('avatars stays public, 5MB, image mimes',
  $q$select public = true and file_size_limit = 5242880 and 'image/jpg' = any(allowed_mime_types) and 'image/png' = any(allowed_mime_types)
     from storage.buckets where id = 'avatars'$q$);

-- 9) spatial_ref_sys: informational (migration role may be unable to revoke)
select pg_temp.rec('INFO anon select on spatial_ref_sys',
  'INFO', has_table_privilege('anon', 'public.spatial_ref_sys', 'select')::text);

select n, status, label, detail from results order by n;

rollback;
