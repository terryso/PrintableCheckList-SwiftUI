-- A client cancellation can be observed after the provider has returned but
-- before the Edge Function can return the draft. Keep that operation out of
-- the monthly allowance and do not retain a draft that was never delivered.
create or replace function public.release_managed_ai_operation(
    p_operation_id uuid,
    p_failure_code text
)
returns void
language sql
security definer
set search_path = public, pg_temp
as $$
    update public.managed_ai_operations
    set state = 'released',
        response = case
            when state = 'completed' then null
            else response
        end,
        completed_at = case
            when state = 'completed' then null
            else completed_at
        end,
        failure_code = left(coalesce(p_failure_code, 'unknown_failure'), 120),
        released_at = now(),
        updated_at = now()
    where operation_id = p_operation_id
      and (
          state = 'reserved'
          or (state = 'completed' and p_failure_code = 'operation_cancelled')
      );
$$;
