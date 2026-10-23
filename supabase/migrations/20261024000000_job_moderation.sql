create table if not exists public.job_reports (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs(id) on delete cascade,
  reporter_id uuid not null references auth.users(id) on delete cascade,
  reason text not null check (
    reason in ('scam', 'misleading', 'inappropriate', 'contact_abuse', 'other')
  ),
  details text check (details is null or length(details) <= 1000),
  status text not null default 'pending' check (
    status in ('pending', 'reviewed', 'actioned', 'dismissed')
  ),
  created_at timestamptz not null default now(),
  unique (job_id, reporter_id)
);

alter table public.job_reports enable row level security;

drop policy if exists "Users can submit job reports" on public.job_reports;
create policy "Users can submit job reports" on public.job_reports
  for insert to authenticated
  with check (reporter_id = auth.uid() and status = 'pending');

drop policy if exists "Users can read own reports" on public.job_reports;
create policy "Users can read own reports" on public.job_reports
  for select to authenticated
  using (
    reporter_id = auth.uid()
    or exists (
      select 1
      from public.profiles
      where profiles.id = auth.uid()
        and (
          profiles.is_admin
          or lower(coalesce(profiles.role, '')) in ('admin', 'superadmin')
        )
    )
  );

drop policy if exists "Admins can update job reports" on public.job_reports;
create policy "Admins can update job reports" on public.job_reports
  for update to authenticated
  using (
    exists (
      select 1
      from public.profiles
      where profiles.id = auth.uid()
        and (
          profiles.is_admin
          or lower(coalesce(profiles.role, '')) in ('admin', 'superadmin')
        )
    )
  )
  with check (
    exists (
      select 1
      from public.profiles
      where profiles.id = auth.uid()
        and (
          profiles.is_admin
          or lower(coalesce(profiles.role, '')) in ('admin', 'superadmin')
        )
    )
  );

create table if not exists public.blocked_employers (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  employer_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, employer_id),
  check (blocker_id <> employer_id)
);

alter table public.blocked_employers enable row level security;

drop policy if exists "Users can read their blocked employers" on public.blocked_employers;
create policy "Users can read their blocked employers" on public.blocked_employers
  for select to authenticated
  using (blocker_id = auth.uid());

drop policy if exists "Users can block employers" on public.blocked_employers;
create policy "Users can block employers" on public.blocked_employers
  for insert to authenticated
  with check (
    blocker_id = auth.uid()
    and blocker_id <> employer_id
  );

drop policy if exists "Users can unblock employers" on public.blocked_employers;
create policy "Users can unblock employers" on public.blocked_employers
  for delete to authenticated
  using (blocker_id = auth.uid());

revoke insert, update on public.job_reports from authenticated;
grant insert (job_id, reporter_id, reason, details)
  on public.job_reports to authenticated;
grant update (status) on public.job_reports to authenticated;
grant select on public.job_reports to authenticated;
grant insert, select, delete on public.blocked_employers to authenticated;

notify pgrst, 'reload schema';
