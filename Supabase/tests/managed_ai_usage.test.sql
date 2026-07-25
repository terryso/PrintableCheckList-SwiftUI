-- Run only against a disposable local Supabase database after migrations:
--   psql "$LOCAL_SUPABASE_DB_URL" -v ON_ERROR_STOP=1 \
--     -f Supabase/tests/managed_ai_usage.test.sql
--
-- The transaction is rolled back so repeated runs start from the same state.

begin;

do $$
declare
    v_account text := 'managed-ai-ledger-test-transaction';
    v_operation uuid := '00000000-0000-4000-8000-000000000001';
    v_conflicting_account text := 'managed-ai-ledger-conflicting-transaction';
    v_expired_operation uuid := '00000000-0000-4000-8000-000000000022';
    v_recovery_operation uuid := '00000000-0000-4000-8000-000000000023';
    v_result record;
    v_active_count integer;
    v_limit_was_reached boolean := false;
    v_operation_conflicted boolean := false;
    v_index integer;
begin
    delete from public.managed_ai_accounts
    where original_transaction_id = v_account;

    select *
    into v_result
    from public.reserve_managed_ai_operation(
        v_account,
        'Sandbox',
        v_operation,
        'America/Los_Angeles'
    );

    assert v_result.operation_state = 'reserved',
        'the first operation must be reserved';
    assert v_result.effective_time_zone = 'America/Los_Angeles',
        'the first valid IANA time zone must become effective';
    assert v_result.calendar_month = date_trunc(
        'month',
        now() at time zone 'America/Los_Angeles'
    )::date, 'the quota month must use the account time zone';

    select *
    into v_result
    from public.reserve_managed_ai_operation(
        v_account,
        'Sandbox',
        v_operation,
        'Asia/Shanghai'
    );
    assert v_result.operation_state = 'in_progress',
        'a repeated active operation ID must not reserve twice';
    assert v_result.effective_time_zone = 'America/Los_Angeles',
        'later device time zones must not move the account month boundary';

    perform public.complete_managed_ai_operation(
        v_operation,
        '{"draft":{"title":"Trip","items":["Passport"]},"sources":[],"did_search":false}'::jsonb
    );
    select *
    into v_result
    from public.reserve_managed_ai_operation(
        v_account,
        'Sandbox',
        v_operation,
        'America/Los_Angeles'
    );
    assert v_result.operation_state = 'completed',
        'a completed operation ID must replay without another reservation';
    assert v_result.stored_response #>> '{draft,title}' = 'Trip',
        'a completed replay must return the original response';

    perform public.release_managed_ai_operation(v_operation, 'operation_cancelled');
    assert exists (
        select 1
        from public.managed_ai_operations
        where operation_id = v_operation
          and state = 'released'
          and response is null
          and failure_code = 'operation_cancelled'
    ), 'a cancellation observed after completion must release the operation without retaining a draft';

    select *
    into v_result
    from public.reserve_managed_ai_operation(
        v_account,
        'Sandbox',
        v_operation,
        'America/Los_Angeles'
    );
    assert v_result.operation_state = 'reserved',
        'a released cancelled operation must restore the allowance';

    begin
        perform public.reserve_managed_ai_operation(
            v_conflicting_account,
            'Sandbox',
            v_operation,
            'Asia/Shanghai'
        );
    exception
        when others then
            if sqlerrm = 'operation_id_conflict' then
                v_operation_conflicted := true;
            else
                raise;
            end if;
    end;
    assert v_operation_conflicted,
        'another Pro identity must not reuse an operation ID';

    for v_index in 2..20 loop
        perform public.reserve_managed_ai_operation(
            v_account,
            'Sandbox',
            (
                '00000000-0000-4000-8000-' ||
                lpad(v_index::text, 12, '0')
            )::uuid,
            'America/Los_Angeles'
        );
    end loop;

    select count(*)
    into v_active_count
    from public.managed_ai_operations as operation
    join public.managed_ai_accounts as account
      on account.id = operation.account_id
    where account.original_transaction_id = v_account
      and operation.state in ('reserved', 'completed');
    assert v_active_count = 20,
        'exactly 20 active operations must be allowed';

    begin
        perform public.reserve_managed_ai_operation(
            v_account,
            'Sandbox',
            '00000000-0000-4000-8000-000000000021',
            'America/Los_Angeles'
        );
    exception
        when others then
            if sqlerrm = 'monthly_limit_reached' then
                v_limit_was_reached := true;
            else
                raise;
            end if;
    end;
    assert v_limit_was_reached,
        'the 21st active operation must be rejected';

    perform public.release_managed_ai_operation(
        '00000000-0000-4000-8000-000000000020',
        'provider_unavailable'
    );
    select *
    into v_result
    from public.reserve_managed_ai_operation(
        v_account,
        'Sandbox',
        '00000000-0000-4000-8000-000000000021',
        'America/Los_Angeles'
    );
    assert v_result.operation_state = 'reserved',
        'a released failure must restore one operation of allowance';

    perform public.release_managed_ai_operation(
        '00000000-0000-4000-8000-000000000021',
        'client_cancelled'
    );
    perform public.reserve_managed_ai_operation(
        v_account,
        'Sandbox',
        v_expired_operation,
        'America/Los_Angeles'
    );
    update public.managed_ai_operations
    set reservation_expires_at = now() - interval '1 second'
    where operation_id = v_expired_operation;

    select *
    into v_result
    from public.reserve_managed_ai_operation(
        v_account,
        'Sandbox',
        v_recovery_operation,
        'America/Los_Angeles'
    );
    assert v_result.operation_state = 'reserved',
        'a new operation must recover allowance from an expired reservation';
    assert exists (
        select 1
        from public.managed_ai_operations
        where operation_id = v_expired_operation
          and state = 'released'
          and failure_code = 'reservation_expired'
    ), 'an expired reservation must be released before applying the monthly limit';

    assert date_trunc(
        'month',
        '2026-08-01 00:30:00+00'::timestamptz
            at time zone 'America/Los_Angeles'
    )::date = '2026-07-01'::date,
        'a west-of-UTC account must remain in July before local midnight';
    assert date_trunc(
        'month',
        '2026-08-01 00:30:00+00'::timestamptz
            at time zone 'Asia/Shanghai'
    )::date = '2026-08-01'::date,
        'an east-of-UTC account must enter August after local midnight';
end;
$$;

rollback;
