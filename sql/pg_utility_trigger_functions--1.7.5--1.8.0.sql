-- Complain if script is sourced in `psql`, rather than via `CREATE EXTENSION`.
\echo Use "CREATE EXTENSION pg_utility_trigger_functions" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

-- Implement 2 missing modes.
create or replace function coalesce_sibling_fields()
    returns trigger
    set search_path from current
    language plpgsql
    as $$
declare
    _select_expressions text;
    _field_values record;
begin
    assert tg_when = 'BEFORE';
    assert tg_op in ('INSERT', 'UPDATE');
    assert tg_level = 'ROW';
    assert tg_nargs >= 1;

    if tg_argv[0] ~ '=>' then
        assert tg_nargs = 1, 'Only a single `hstore` argument may be given.';
        _select_expressions := (
            select
                string_agg(
                    'coalesce(($1).' || quote_ident(e.key) || ', ($1).' || quote_ident(e.value)
                        || ') AS ' || quote_ident(e.key)
                    ,', '
                )
            from
                each(hstore(tg_argv[0])) as e(key, value)
        );
    elsif substr(tg_argv[0], 1, 1) = '{' then
        _select_expressions := (
            select
                string_agg(agg.coalesce_expression, ', ')
            from (
                select
                    'coalesce(($1).' || string_agg(quote_ident(d2.column_name), ', ($1).')
                        || ') AS ' || quote_ident(d1.arr[1]) as coalesce_expression
                from
                    unnest(tg_argv) with ordinality as arg(array_string, n)
                cross join lateral (
                    select
                        arg.array_string::text[] as arr
                    ) as d1
                cross join lateral
                    unnest(d1.arr) with ordinality as d2(column_name, n)
                group by
                    d1.arr
            ) as agg
        );
    else
        assert tg_nargs > 1;
        _select_expressions := (
            select
                'coalesce(($1).' || string_agg(quote_ident(arg.field_name), ', ($1).')
                    || ') AS ' || quote_ident(tg_argv[0])
            from
                unnest(tg_argv) as arg(field_name)
        );
    end if;

    execute 'SELECT ' || _select_expressions
        using NEW
        into _field_values;

    return NEW #= hstore(_field_values);
end;
$$;

-- All these modes are implemented now.
comment on function coalesce_sibling_fields() is
$md$When a given column is `NULL`, this trigger function will coalesce it with one or more other given columns.

`coalesce_sibling_fields()` trigger function should be able to function in 3
different modes, depending on its argument given in the `CREATE TRIGGER`
definition:

  1. When multiple non-array arguments are given, the second argument and so
     forth will be the fallback values for the first value.
  2. When one or more array arguments are given, each of these array will be
     treated as the different function arguments as in the second mode.
  3. When a single `hstore` argument is supplied, each key in that `hstore` is
     treated as the preferred column and each value as the fallback value, as in
     `key = coalesce(key, value)`.
$md$;

--------------------------------------------------------------------------------------------------------------

create or replace procedure test__coalesce_sibling_fields()
    set search_path from current
    set plpgsql.check_asserts to true
    set pg_readme.include_this_routine_definition to true
    language plpgsql
    as $$
declare
    _rec record;
begin
    create table test__tbl (a text, b text, c text, x text, y text, z text);
    create trigger coalesce_with_hstore_arg
        before insert on test__tbl
        for each row
        execute function coalesce_sibling_fields('a => b, x => y');

    insert into test__tbl
        (a, b, x, y)
    values
        (null, 'teenager', null, 'boot')
    returning
        *
    into
        _rec
    ;
    assert _rec.a = 'teenager';
    assert _rec.x = 'boot';

    insert into test__tbl
        (a, b, x, y)
    values
        ('adult', 'teenager', 'slipper', 'boot')
    returning
        *
    into
        _rec
    ;
    assert _rec.a = 'adult';
    assert _rec.x = 'slipper';

    drop trigger coalesce_with_hstore_arg
        on test__tbl;

    ---

    create trigger coalesce_with_multiple_args
        before insert on test__tbl
        for each row
        execute function coalesce_sibling_fields('a', 'b', 'c');

    insert into test__tbl
        (a, b, c)
    values
        (null, null, 'child')
    returning
        *
    into
        _rec
    ;
    assert _rec.a = 'child';

    insert into test__tbl
        (a, b, c)
    values
        ('adult', null, 'child')
    returning
        *
    into
        _rec
    ;
    assert _rec.a = 'adult';

    drop trigger coalesce_with_multiple_args
        on test__tbl;

    ---

    create trigger coalesce_with_array_args
        before insert on test__tbl
        for each row
        execute function coalesce_sibling_fields('{a, b, c}', '{x, y}');

    insert into test__tbl
        (a, b, c, x, y)
    values
        (null, null, 'child', null, 'boot')
    returning
        *
    into
        _rec
    ;
    assert _rec.a = 'child';
    assert _rec.x = 'boot';

    insert into test__tbl
        (a, b, c, x, y)
    values
        ('adult', null, 'child', 'slipper', 'boot')
    returning
        *
    into
        _rec
    ;
    assert _rec.a = 'adult';
    assert _rec.x = 'slipper';

    raise transaction_rollback;
exception
    when transaction_rollback then
end;
$$;

--------------------------------------------------------------------------------------------------------------
