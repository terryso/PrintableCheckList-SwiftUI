create table if not exists public.checklist_snapshots (
    owner_id uuid primary key references auth.users(id) on delete cascade,
    payload jsonb not null check (jsonb_typeof(payload) = 'array'),
    updated_at timestamptz not null default now()
);

alter table public.checklist_snapshots enable row level security;

revoke all on table public.checklist_snapshots from anon;
grant select, insert, update on table public.checklist_snapshots to authenticated;

drop policy if exists "Users can read their own checklist snapshot"
on public.checklist_snapshots;
create policy "Users can read their own checklist snapshot"
on public.checklist_snapshots
for select
to authenticated
using ((select auth.uid()) = owner_id);

drop policy if exists "Users can create their own checklist snapshot"
on public.checklist_snapshots;
create policy "Users can create their own checklist snapshot"
on public.checklist_snapshots
for insert
to authenticated
with check ((select auth.uid()) = owner_id);

drop policy if exists "Users can update their own checklist snapshot"
on public.checklist_snapshots;
create policy "Users can update their own checklist snapshot"
on public.checklist_snapshots
for update
to authenticated
using ((select auth.uid()) = owner_id)
with check ((select auth.uid()) = owner_id);
