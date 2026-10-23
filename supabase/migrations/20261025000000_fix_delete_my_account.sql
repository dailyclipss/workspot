-- Make every foreign key that points at auth.users cascade on delete,
-- otherwise deleting the user fails when related rows exist.
do $$
declare
  fk record;
  cols text;
  refcols text;
begin
  for fk in
    select c.oid, c.conname, c.conrelid::regclass as tbl, c.conkey, c.confkey,
           c.confrelid
    from pg_constraint c
    where c.contype = 'f'
      and c.confrelid = 'auth.users'::regclass
      and c.confdeltype in ('a', 'r')
      and c.connamespace = 'public'::regnamespace
  loop
    select string_agg(quote_ident(a.attname), ', ') into cols
    from pg_attribute a
    where a.attrelid = fk.conrelid::regclass and a.attnum = any (fk.conkey);

    select string_agg(quote_ident(a.attname), ', ') into refcols
    from pg_attribute a
    where a.attrelid = fk.confrelid and a.attnum = any (fk.confkey);

    execute format('alter table %s drop constraint %I', fk.tbl, fk.conname);
    execute format(
      'alter table %s add constraint %I foreign key (%s) references auth.users (%s) on delete cascade',
      fk.tbl, fk.conname, cols, refcols
    );
  end loop;
end;
$$;

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
