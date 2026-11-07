-- Phase 1 hardening: profiles, avatars/resumes storage, spatial_ref_sys.
-- Compatible with app 1.0.0 (30): the client only reads/writes its OWN profiles
-- row (id, full_name, profession, phone, updated_at, cv_path, cv_name) and uploads
-- avatars/resumes under "<auth.uid()>/...".

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------

-- Legacy dashboard-created policies: public SELECT exposed every phone number.
drop policy if exists "Public profiles are viewable by everyone." on public.profiles;
drop policy if exists "Users can insert their own profile." on public.profiles;
drop policy if exists "Users can update their own profile." on public.profiles;

-- The *_own policies stay (id = auth.uid()); make sure they exist.
drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own" on public.profiles
  for select to authenticated using (id = auth.uid());

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own" on public.profiles
  for insert to authenticated with check (id = auth.uid());

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles
  for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- Table-wide INSERT was still granted, so a user without a profile row could
-- insert one with is_admin = true / role = 'admin'. Reset and grant only the
-- columns the app writes. is_admin and role are never client-writable.
revoke all on public.profiles from anon;
revoke insert, update, delete, truncate, references, trigger
  on public.profiles from authenticated;

grant select on public.profiles to authenticated;
grant insert (id, full_name, phone, profession, updated_at, cv_path, cv_name)
  on public.profiles to authenticated;
grant update (full_name, phone, profession, updated_at, cv_path, cv_name)
  on public.profiles to authenticated;

-- ---------------------------------------------------------------------------
-- storage: resumes (private) and avatars (public read, own-folder write)
-- ---------------------------------------------------------------------------

-- The app never reads CVs through a public URL; it only uploads them.
update storage.buckets
   set public = false,
       file_size_limit = 10485760,
       allowed_mime_types = array['application/pdf']
 where id = 'resumes';

update storage.buckets
   set file_size_limit = 5242880,
       allowed_mime_types = array[
         'image/jpeg', 'image/jpg', 'image/png', 'image/webp',
         'image/heic', 'image/heif'
       ]
 where id = 'avatars';

-- Anonymous/anyone could upload unlimited files into avatars.
drop policy if exists "Public Insert Access" on storage.objects;

drop policy if exists "avatars_insert_own" on storage.objects;
create policy "avatars_insert_own" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "avatars_update_own" on storage.objects;
create policy "avatars_update_own" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "avatars_delete_own" on storage.objects;
create policy "avatars_delete_own" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- "Public Read Access" (select on avatars) is kept: getPublicUrl keeps working.

-- ---------------------------------------------------------------------------
-- spatial_ref_sys (PostGIS table owned by supabase_admin)
-- ---------------------------------------------------------------------------
-- Best effort: if the migration role is not allowed to change these grants,
-- keep going instead of failing the whole migration.
do $$
begin
  revoke all on public.spatial_ref_sys from anon, authenticated;
exception when others then
  raise notice 'spatial_ref_sys grants not changed: %', sqlerrm;
end;
$$;

notify pgrst, 'reload schema';
