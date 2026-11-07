-- Payment records are kept for accounting, but detached from the deleted user.
-- transactions/payment_requests have no FK to auth.users, so without this the
-- rows would keep pointing at the removed user id.
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public, auth, storage
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  update public.transactions
     set user_id = null,
         company_id = null
   where user_id = uid::text;

  -- note is free text, so it is cleared; reference/transaction_note only hold
  -- payment identifiers (no personal data) and are kept for reconciliation.
  update public.payment_requests
     set user_id = null,
         note = null
   where user_id = uid;

  -- Supabase may block direct deletes on storage.objects; do not fail the whole deletion.
  begin
    delete from storage.objects
    where bucket_id = 'resumes'
      and name like uid::text || '/%';
  exception when others then
    null;
  end;

  delete from auth.users where id = uid;
end;
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;

notify pgrst, 'reload schema';
