-- Keep this corrective migration separate from the original definition because
-- deployed Supabase migration history is append-only and must not be rewritten.
create or replace function public.reserve_managed_ai_operation(
    p_original_transaction_id text,
    p_app_store_environment text,
    p_operation_id uuid,
    p_requested_time_zone text
)
returns table (
    operation_state text,
    effective_time_zone text,
    calendar_month date,
    stored_response jsonb
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
    v_account public.managed_ai_accounts%rowtype;
    v_operation public.managed_ai_operations%rowtype;
    v_calendar_month date;
    v_active_operation_count integer;
begin
    if p_app_store_environment not in ('Sandbox', 'Production') then
        raise exception using errcode = '22023', message = 'invalid_app_store_environment';
    end if;

    if p_requested_time_zone is null
       or not exists (
           select 1
           from pg_timezone_names
           where name = p_requested_time_zone
       )
    then
        raise exception using errcode = '22023', message = 'invalid_time_zone';
    end if;

    insert into public.managed_ai_accounts (
        original_transaction_id,
        app_store_environment,
        effective_time_zone
    )
    values (
        p_original_transaction_id,
        p_app_store_environment,
        p_requested_time_zone
    )
    on conflict (original_transaction_id) do nothing;

    select *
    into v_account
    from public.managed_ai_accounts
    where original_transaction_id = p_original_transaction_id
    for update;

    if v_account.app_store_environment <> p_app_store_environment then
        raise exception using errcode = '22023', message = 'app_store_environment_mismatch';
    end if;

    if v_account.effective_time_zone is null then
        update public.managed_ai_accounts
        set effective_time_zone = p_requested_time_zone,
            updated_at = now()
        where id = v_account.id
        returning * into v_account;
    end if;

    v_calendar_month := date_trunc(
        'month',
        now() at time zone v_account.effective_time_zone
    )::date;

    update public.managed_ai_operations as expired_operation
    set state = 'released',
        failure_code = 'reservation_expired',
        released_at = now(),
        updated_at = now()
    where expired_operation.account_id = v_account.id
      and expired_operation.calendar_month = v_calendar_month
      and expired_operation.state = 'reserved'
      and expired_operation.reservation_expires_at < now();

    select *
    into v_operation
    from public.managed_ai_operations
    where operation_id = p_operation_id
    for update;

    if found then
        if v_operation.account_id <> v_account.id then
            raise exception using errcode = '22023', message = 'operation_id_conflict';
        end if;

        if v_operation.state = 'completed' then
            return query
            select 'completed', v_account.effective_time_zone, v_operation.calendar_month, v_operation.response;
            return;
        end if;

        if v_operation.state = 'reserved'
           and v_operation.reservation_expires_at >= now()
        then
            return query
            select 'in_progress', v_account.effective_time_zone, v_operation.calendar_month, null::jsonb;
            return;
        end if;
    end if;

    select count(*)
    into v_active_operation_count
    from public.managed_ai_operations as active_operation
    where active_operation.account_id = v_account.id
      and active_operation.calendar_month = v_calendar_month
      and active_operation.state in ('reserved', 'completed');

    if v_active_operation_count >= 20 then
        raise exception using errcode = 'P0001', message = 'monthly_limit_reached';
    end if;

    insert into public.managed_ai_operations (
        operation_id,
        account_id,
        calendar_month,
        state,
        reserved_at,
        reservation_expires_at,
        updated_at
    )
    values (
        p_operation_id,
        v_account.id,
        v_calendar_month,
        'reserved',
        now(),
        now() + interval '10 minutes',
        now()
    )
    on conflict (operation_id) do update
    set account_id = excluded.account_id,
        calendar_month = excluded.calendar_month,
        state = 'reserved',
        response = null,
        failure_code = null,
        reserved_at = now(),
        reservation_expires_at = now() + interval '10 minutes',
        completed_at = null,
        released_at = null,
        updated_at = now();

    return query
    select 'reserved', v_account.effective_time_zone, v_calendar_month, null::jsonb;
end;
$$;
