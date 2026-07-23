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
    v_result record;
    v_active_count integer;
    v_limit_was_reached boolean := false;
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
