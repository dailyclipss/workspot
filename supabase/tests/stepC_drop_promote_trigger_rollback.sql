-- Rollback-only check for 20261108020000_drop_promote_job_trigger.sql.
-- Run as: begin; <migration>; <this file>. Ends with ROLLBACK.
create temp table results (n serial, label text, status text, detail text);

insert into results (label, status, detail)
select 'trigger removed',
  case when not exists (select 1 from pg_trigger where tgname = 'trigger_promote_job_vip') then 'PASS' else 'FAIL' end, null;

insert into results (label, status, detail)
select 'function removed',
  case when not exists (select 1 from pg_proc where proname = 'promote_job_on_transaction'
                        and pronamespace = 'public'::regnamespace) then 'PASS' else 'FAIL' end, null;

insert into results (label, status, detail)
select 'jobs guard trigger still present',
  case when exists (select 1 from pg_trigger where tgname = 'jobs_guard_privileged_columns') then 'PASS' else 'FAIL' end, null;

select n, label, status, detail from results order by n;
select count(*) filter (where status = 'PASS') as pass, count(*) filter (where status = 'FAIL') as fail from results;

rollback;
