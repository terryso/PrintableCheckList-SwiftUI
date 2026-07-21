grant delete on table public.checklist_snapshots to authenticated;

drop policy if exists "Users can delete their own checklist snapshot"
on public.checklist_snapshots;
create policy "Users can delete their own checklist snapshot"
on public.checklist_snapshots
for delete
to authenticated
using ((select auth.uid()) = owner_id);
