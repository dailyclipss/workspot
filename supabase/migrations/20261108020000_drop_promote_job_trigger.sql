-- Removes the dashboard-created trigger that made any job with a transactions row a 30-day VIP.
-- VIP is now granted only by epoint-callback (service_role) or the admin RPCs.
drop trigger if exists trigger_promote_job_vip on public.transactions;
drop function if exists public.promote_job_on_transaction();
