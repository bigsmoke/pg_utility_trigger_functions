-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION pg_utility_trigger_functions" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

create function coalesce_sibling_fields()
    returns trigger
    set search_path from current
    language plpgsql
    as $$
declare
    _field_mappings hstore;
    _field_values record;
begin
    assert tg_when = 'BEFORE';
    assert tg_op in ('INSERT', 'UPDATE');
    assert tg_level = 'ROW';
    assert tg_nargs = 1;

    _field_mappings := hstore(tg_argv[0]);

    execute 'SELECT '
            || (
                select
                    string_agg(
                        'coalesce(($1).' || quote_ident(f.key) || ', ($1).' || quote_ident(f.value)
                        || ') AS ' || quote_ident(f.key)
                        ,', '
                    )
                from
                    each(_field_mappings) as f
            )
        using NEW
        into _field_values;

    return NEW #= hstore(_field_values);
end;
$$;

--------------------------------------------------------------------------------------------------------------

create procedure test__coalesce_sibling_fields()
    set search_path from current
    set plpgsql.check_asserts to true
    set pg_readme.include_this_routine_definition to true
    language plpgsql
    as $$
declare
    _rec record;
begin
    create table test__tbl (a text, b text);
    create trigger coalesce_a_to_b
        before insert on test__tbl
        for each row
        execute function coalesce_sibling_fields('a => b');

    insert into test__tbl
        (a, b)
    values
        (null, 'teenager')
    returning
        *
    into
        _rec
    ;
    assert _rec.a = 'teenager';


    insert into test__tbl
        (a, b)
    values
        ('adult', 'teenager')
    returning
        *
    into
        _rec
    ;
    assert _rec.a = 'adult';

    raise transaction_rollback;
exception
    when transaction_rollback then
end;
$$;

--------------------------------------------------------------------------------------------------------------
