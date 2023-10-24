-- Complain if script is sourced in `psql`, rather than via `CREATE EXTENSION`.
\echo Use "CREATE EXTENSION pg_utility_trigger_functions" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

create function debug_row()
    returns trigger
    language plpgsql
    as $$
begin
    raise notice '% % ON %.%: jsonb_pretty(to_jsonb(OLD.*) = %; jsonb_pretty(to_jsonb(NEW.*)) = %',
        tg_when, tg_op, quote_ident(tg_table_schema), quote_ident(tg_table_name)
        ,jsonb_pretty(to_jsonb(OLD.*)), jsonb_pretty(to_jsonb(NEW.*));

    if tg_when = 'BEFORE' and tg_op in ('INSERT', 'UPDATE') then
        return NEW;
    end if;

    if tg_when = 'BEFORE' and tg_op = 'DELETE' then
        return OLD;
    end if;

    return null;
end;
$$;

comment on function debug_row() is
$md$A simple trigger function to help you output the OLD and NEW row BEFORE or AFTER any operation on a ROW.
$md$;

--------------------------------------------------------------------------------------------------------------
